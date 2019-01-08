import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class ThemeGridControllerInteraction {
    let openWallpaper: (TelegramWallpaper) -> Void
    
    init(openWallpaper: @escaping (TelegramWallpaper) -> Void) {
        self.openWallpaper = openWallpaper
    }
}

private struct ThemeGridControllerEntry: Comparable, Identifiable {
    let index: Int
    let wallpaper: TelegramWallpaper
    let selected: Bool
    
    static func ==(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index == rhs.index && lhs.wallpaper == rhs.wallpaper && lhs.selected == rhs.selected
    }
    
    static func <(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: Int {
        return self.index
    }
    
    func item(account: Account, interaction: ThemeGridControllerInteraction) -> ThemeGridControllerItem {
        return ThemeGridControllerItem(account: account, wallpaper: self.wallpaper, selected: self.selected, interaction: interaction)
    }
}

private struct ThemeGridEntryTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
}

private func preparedThemeGridEntryTransition(account: Account, from fromEntries: [ThemeGridControllerEntry], to toEntries: [ThemeGridControllerEntry], interaction: ThemeGridControllerInteraction) -> ThemeGridEntryTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction)) }
    
    return ThemeGridEntryTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: nil, stationaryItems: stationaryItems, scrollToItem: scrollToItem)
}

final class ThemeGridControllerNode: ASDisplayNode {
    private let account: Account
    private var presentationData: PresentationData
    
    private let present: (ViewController, Any?) -> Void
    private let selectCustomWallpaper: () -> Void
    var requestDeactivateSearch: (() -> Void)?
    
    let ready = ValuePromise<Bool>()
    
    private var customWallpaperBackground: ASDisplayNode
    private var customWallpaperSeparator: ASDisplayNode
        
    private let customWallpaperButton: HighlightableButtonNode
    private var customWallpaperButtonBackground: ASDisplayNode
    private var customWallpaperButtonTopSeparator: ASDisplayNode
    private var customWallpaperButtonBottomSeparator: ASDisplayNode
    private var customWallpaperLabel: ASTextNode
    
    let gridNode: GridNode
    var navigationBar: NavigationBar?
    
    private var queuedTransitions: [ThemeGridEntryTransition] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    private var disposable: Disposable?
    
    init(account: Account, presentationData: PresentationData, mode: ThemeGridControllerMode, present: @escaping (ViewController, Any?) -> Void, selectCustomWallpaper: @escaping () -> Void) {
        self.account = account
        self.presentationData = presentationData
        self.present = present
        self.selectCustomWallpaper = selectCustomWallpaper
        
        self.gridNode = GridNode()
        self.gridNode.showVerticalScrollIndicator = true
        
        self.customWallpaperButton = HighlightableButtonNode()
        self.customWallpaperButton.contentHorizontalAlignment = .left
        
        self.customWallpaperButtonBackground = ASDisplayNode()
        self.customWallpaperButtonBackground.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        
        self.customWallpaperBackground = ASDisplayNode()
        self.customWallpaperBackground.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        self.customWallpaperSeparator = ASDisplayNode()
        self.customWallpaperSeparator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.customWallpaperButtonTopSeparator = ASDisplayNode()
        self.customWallpaperButtonTopSeparator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.customWallpaperButtonBottomSeparator = ASDisplayNode()
        self.customWallpaperButtonBottomSeparator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.customWallpaperLabel = ASTextNode()
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        
        self.customWallpaperButton.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Wallpaper_SetCustomBackground, font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor), for: [])
        self.customWallpaperButton.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        self.customWallpaperButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.customWallpaperButton.backgroundColor = strongSelf.presentationData.theme.list.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.customWallpaperButton.backgroundColor = nil
                    })
                }
            }
        }
        
        self.customWallpaperLabel.attributedText = NSAttributedString(string: self.presentationData.strings.Wallpaper_SetCustomBackgroundInfo, font: Font.regular(14.0), textColor: self.presentationData.theme.list.freeTextColor)
        
        self.gridNode.addSubnode(self.customWallpaperBackground)
        self.gridNode.addSubnode(self.customWallpaperSeparator)
        self.gridNode.addSubnode(self.customWallpaperButtonTopSeparator)
        self.gridNode.addSubnode(self.customWallpaperButtonBottomSeparator)
        self.gridNode.addSubnode(self.customWallpaperButtonBackground)
        self.gridNode.addSubnode(self.customWallpaperButton)
        self.gridNode.addSubnode(self.customWallpaperLabel)
        self.addSubnode(self.gridNode)
        
        let previousEntries = Atomic<[ThemeGridControllerEntry]?>(value: nil)
        
        let interaction = ThemeGridControllerInteraction(openWallpaper: { [weak self] wallpaper in
            if let strongSelf = self {
                let entries = previousEntries.with { $0 }
                if let entries = entries, !entries.isEmpty {
                    let wallpapers = entries.map { $0.wallpaper }
                    let controller = WallpaperListPreviewController(account: account, source: .list(wallpapers: wallpapers, central: wallpaper))
                    strongSelf.present(controller, nil)
                    //let controller = ThemeGalleryController(account: account, wallpapers: wallpapers, at: wallpaper)
                    //strongSelf.present(controller, ThemePreviewControllerPresentationArguments(transitionArguments: { entry -> GalleryTransitionArguments? in
                    //    return nil
                    //}))
                }
            }
        })
        
        let transition = combineLatest(telegramWallpapers(postbox: account.postbox, network: account.network), account.telegramApplicationContext.presentationData)
        |> map { wallpapers, presentationData -> (ThemeGridEntryTransition, Bool) in
            var entries: [ThemeGridControllerEntry] = []
            var index = 1
            
            var hasCurrent = false
            switch presentationData.theme.name {
                case let .builtin(name):
                    switch name {
                        case .dayClassic:
                            break
                        case .day:
                            let wallpaper = TelegramWallpaper.color(0xffffff)
                            let selected = presentationData.chatWallpaper == wallpaper
                            entries.append(ThemeGridControllerEntry(index: index, wallpaper: wallpaper, selected: selected))
                            hasCurrent = hasCurrent || selected
                            index += 1
                        case .nightGrayscale:
                            let wallpaper = TelegramWallpaper.color(0xffffff)
                            let selected = presentationData.chatWallpaper == wallpaper
                            entries.append(ThemeGridControllerEntry(index: index, wallpaper: wallpaper, selected: selected))
                            hasCurrent = hasCurrent || selected
                            index += 1
                        case .nightAccent:
                            let wallpaper = TelegramWallpaper.color(0xffffff)
                            let selected = presentationData.chatWallpaper == wallpaper
                            entries.append(ThemeGridControllerEntry(index: index, wallpaper: wallpaper, selected: selected))
                            hasCurrent = hasCurrent || selected
                            index += 1
                    }
                default:
                    break
            }
            
            for wallpaper in wallpapers {
                let selected = presentationData.chatWallpaper == wallpaper
                entries.append(ThemeGridControllerEntry(index: index, wallpaper: wallpaper, selected: selected))
                hasCurrent = hasCurrent || selected
                index += 1
            }
            
            if !hasCurrent {
                entries.insert(ThemeGridControllerEntry(index: 0, wallpaper: presentationData.chatWallpaper, selected: true), at: 0)
            }
            
            let previous = previousEntries.swap(entries)
            return (preparedThemeGridEntryTransition(account: account, from: previous ?? [], to: entries, interaction: interaction), previous == nil)
        }
        self.disposable = (transition |> deliverOnMainQueue).start(next: { [weak self] (transition, _) in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition)
            }
        })
        
        self.customWallpaperButton.addTarget(self, action: #selector(self.customWallpaperPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.searchDisplayController?.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
    }
    
    private func enqueueTransition(_ transition: ThemeGridEntryTransition) {
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
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        let scrollIndicatorInsets = insets
        
        let referenceImageSize = CGSize(width: 108.0, height: 230.0)
        
        let minSpacing: CGFloat = 8.0
        
        let imageCount = Int((layout.size.width - minSpacing * 2.0) / (referenceImageSize.width + minSpacing))
        
        let imageSize = referenceImageSize.aspectFilled(CGSize(width: floor((layout.size.width - CGFloat(imageCount + 1) * minSpacing) / CGFloat(imageCount)), height: referenceImageSize.height))
        
        let spacing = floor((layout.size.width - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount + 1))
        
        let textInset: CGFloat = 15.0
        let textSize = self.customWallpaperLabel.measure(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - textInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        let buttonTopInset: CGFloat = 32.0
        let buttonHeight: CGFloat = 44.0
        let buttonBottomInset: CGFloat = textSize.height + 6.0 + 25.0
        
        let buttonInset: CGFloat = buttonTopInset + buttonHeight + buttonBottomInset
        let buttonOffset = buttonInset + 10.0
        
        self.customWallpaperButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 17.0 + layout.safeInsets.left, bottom: 0.0, right: 0.0)
        
        transition.updateFrame(node: self.customWallpaperBackground, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset - 500.0), size: CGSize(width: layout.size.width, height: buttonTopInset + buttonHeight + buttonBottomInset + 500.0)))
        transition.updateFrame(node: self.customWallpaperSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset + buttonHeight + buttonBottomInset - UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.customWallpaperButtonTopSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset - UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.customWallpaperButtonBottomSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset + buttonHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.customWallpaperButtonBackground, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset), size: CGSize(width: layout.size.width, height: buttonHeight)))
        transition.updateFrame(node: self.customWallpaperButton, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset), size: CGSize(width: layout.size.width, height: buttonHeight)))
        transition.updateFrame(node: self.customWallpaperLabel, frame: CGRect(origin: CGPoint(x: textInset + layout.safeInsets.left, y: -buttonOffset + buttonTopInset + buttonHeight + 6.0), size: textSize))
        
        insets.top += spacing + buttonInset
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: insets, scrollIndicatorInsets: scrollIndicatorInsets, preloadSize: 300.0, type: .fixed(itemSize: imageSize, fillWidth: nil, lineSpacing: spacing, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        self.gridNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        
        let dequeue = self.validLayout == nil
        self.validLayout = (layout, navigationBarHeight)
        if dequeue {
            self.dequeueTransitions()
        }
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    @objc func customWallpaperPressed() {
        self.selectCustomWallpaper()
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.validLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(theme: self.presentationData.theme, strings: self.presentationData.strings, contentNode: ChatListSearchContainerNode(account: self.account, filter: [], groupId: nil, openPeer: { [weak self] peer, dismissSearch in
            
            }, openRecentPeerOptions: { [weak self] peer in
               
            }, openMessage: { [weak self] peer, messageId in
               
            }, addContact: { [weak self] phoneNumber in
              
        }), cancel: { [weak self] in
            self?.requestDeactivateSearch?()
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
        }
    }
    
    func scrollToTop() {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.contentNode.scrollToTop()
        } else {
             self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: GridNodeScrollToItem(index: 0, position: .top, transition: .animated(duration: 0.25, curve: .easeInOut), directionHint: .up, adjustForSection: true, adjustForTopInset: true), updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        }
    }
}
