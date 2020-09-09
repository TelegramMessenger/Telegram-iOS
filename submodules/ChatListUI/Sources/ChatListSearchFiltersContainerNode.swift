import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SyncCore
import Postbox
import TelegramCore
import TelegramPresentationData

enum ChatListSearchFilter: Equatable {
    case media
    case links
    case files
    case music
    case voice
    case date(Int32, String)
    
    var id: Int32 {
        switch self {
            case .media:
                return 0
            case .links:
                return 1
            case .files:
                return 2
            case .music:
                return 3
            case .voice:
                return 4
            case let .date(date, _):
                return date
        }
    }
}

private final class ItemNode: ASDisplayNode {
    private let pressed: () -> Void
    
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private var selectionFraction: CGFloat = 0.0
    private(set) var unreadCount: Int = 0
    
    private var isReordering: Bool = false
    
    private var theme: PresentationTheme?
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
    
        let titleInset: CGFloat = 4.0
                
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.iconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.iconNode.alpha = 0.4
                    
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                } else {
                    strongSelf.iconNode.alpha = 1.0
                    strongSelf.iconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func update(type: ChatListSearchFilter, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        let title: String
        let icon: UIImage?
        
        let color = presentationData.theme.list.itemSecondaryTextColor
        switch type {
            case .media:
                title = presentationData.strings.ChatList_Search_FilterMedia
                icon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Search/Media"), color: color)
            case .links:
                title = presentationData.strings.ChatList_Search_FilterLinks
                icon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Search/Links"), color: color)
            case .files:
                title = presentationData.strings.ChatList_Search_FilterFiles
                icon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Search/Files"), color: color)
            case .music:
                title = presentationData.strings.ChatList_Search_FilterMusic
                icon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Search/Music"), color: color)
            case .voice:
                title = presentationData.strings.ChatList_Search_FilterVoice
                icon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Search/Voice"), color: color)
            case let .date(_, dateTitle):
                title = dateTitle
                icon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Search/Calendar"), color: color)
        }
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(14.0), textColor: color)
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            self.iconNode.image = icon
        }
    }
    
    func updateLayout(height: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let iconInset: CGFloat = 22.0
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(x: 0.0, y: floorToScreenPixels((height - image.size.height) / 2.0), width: image.size.width, height: image.size.height)
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        let titleFrame = CGRect(origin: CGPoint(x: -self.titleNode.insets.left + iconInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
                
        return titleSize.width - self.titleNode.insets.left - self.titleNode.insets.right + iconInset
    }
    
    func updateArea(size: CGSize, sideInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.buttonNode.frame = CGRect(origin: CGPoint(x: -sideInset, y: 0.0), size: CGSize(width: size.width + sideInset * 2.0, height: size.height))

        self.hitTestSlop = UIEdgeInsets(top: 0.0, left: -sideInset, bottom: 0.0, right: -sideInset)
    }
}

enum ChatListSearchFilterEntryId: Hashable {
    case filter(Int32)
}

enum ChatListSearchFilterEntry: Equatable {
    case filter(ChatListSearchFilter)
    
    var id: ChatListSearchFilterEntryId {
        switch self {
        case let .filter(filter):
            return .filter(filter.id)
        }
    }
}

final class ChatListSearchFiltersContainerNode: ASDisplayNode {
    private let scrollNode: ASScrollNode
    private var itemNodes: [ChatListSearchFilterEntryId: ItemNode] = [:]
    
    var filterPressed: ((ChatListSearchFilter) -> Void)?

    private var currentParams: (size: CGSize, sideInset: CGFloat, filters: [ChatListSearchFilterEntry], presentationData: PresentationData)?
        
    override init() {
        self.scrollNode = ASScrollNode()
    
        super.init()
                
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.addSubnode(self.scrollNode)
    }
        
    func cancelAnimations() {
        self.scrollNode.layer.removeAllAnimations()
    }
    
    func update(size: CGSize, sideInset: CGFloat, filters: [ChatListSearchFilterEntry], presentationData: PresentationData, transition proposedTransition: ContainedViewLayoutTransition) {
        let isFirstTime = self.currentParams == nil
        let transition: ContainedViewLayoutTransition = isFirstTime ? .immediate : proposedTransition
        
        if self.currentParams?.presentationData.theme !== presentationData.theme {
            self.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        }
        
        self.currentParams = (size: size, sideInset: sideInset, filters: filters, presentationData: presentationData)
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
             
        for i in 0 ..< filters.count {
            let filter = filters[i]
            if case let .filter(type) = filter {
                let itemNode: ItemNode
                var itemNodeTransition = transition
                if let current = self.itemNodes[filter.id] {
                    itemNode = current
                } else {
                    itemNodeTransition = .immediate
                    itemNode = ItemNode(pressed: { [weak self] in
                        self?.filterPressed?(type)
                    })
                    self.itemNodes[filter.id] = itemNode
                }
                itemNode.update(type: type, presentationData: presentationData, transition: itemNodeTransition)
            }
        }
        var removeKeys: [ChatListSearchFilterEntryId] = []
        for (id, _) in self.itemNodes {
            if !filters.contains(where: { $0.id == id }) {
                removeKeys.append(id)
            }
        }
        for id in removeKeys {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
                transition.updateTransformScale(node: itemNode, scale: 0.1)
            }
        }
        
        var tabSizes: [(ChatListSearchFilterEntryId, CGSize, ItemNode, Bool)] = []
        var totalRawTabSize: CGFloat = 0.0
        
        for filter in filters {
            guard let itemNode = self.itemNodes[filter.id] else {
                continue
            }
            let wasAdded = itemNode.supernode == nil
            var itemNodeTransition = transition
            if wasAdded {
                itemNodeTransition = .immediate
                self.scrollNode.addSubnode(itemNode)
            }
            let paneNodeWidth = itemNode.updateLayout(height: size.height, transition: itemNodeTransition)
            let paneNodeSize = CGSize(width: paneNodeWidth, height: size.height)
            tabSizes.append((filter.id, paneNodeSize, itemNode, wasAdded))
            totalRawTabSize += paneNodeSize.width
        }
        
        let minSpacing: CGFloat = 26.0
        var spacing = minSpacing
        
        let resolvedSideInset: CGFloat = 16.0 + sideInset
        var leftOffset: CGFloat = resolvedSideInset
        
        var longTitlesWidth: CGFloat = resolvedSideInset
        var titlesWidth: CGFloat = 0.0
        for i in 0 ..< tabSizes.count {
            let (_, paneNodeSize, _, _) = tabSizes[i]
            longTitlesWidth += paneNodeSize.width
            titlesWidth += paneNodeSize.width
            if i != tabSizes.count - 1 {
                longTitlesWidth += minSpacing
            }
        }
        longTitlesWidth += resolvedSideInset
        
        if longTitlesWidth < size.width && tabSizes.count > 3 {
            spacing = (size.width - titlesWidth - resolvedSideInset * 2.0) / CGFloat(tabSizes.count - 1)
        }
        
        let verticalOffset: CGFloat = -3.0
        for i in 0 ..< tabSizes.count {
            let (_, paneNodeSize, paneNode, wasAdded) = tabSizes[i]
            var itemNodeTransition = transition
            if wasAdded {
                itemNodeTransition = .immediate
            }
                        
            let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0) + verticalOffset), size: paneNodeSize)
            itemNodeTransition.updateSublayerTransformScale(node: paneNode, scale: 1.0)
            itemNodeTransition.updateAlpha(node: paneNode, alpha: 1.0)
            if wasAdded {
                paneNode.frame = paneFrame
                paneNode.alpha = 0.0
                itemNodeTransition.updateAlpha(node: paneNode, alpha: 1.0)
            } else {
                itemNodeTransition.updateFrameAdditive(node: paneNode, frame: paneFrame)
            }
            
            paneNode.updateArea(size: paneFrame.size, sideInset: spacing / 2.0, transition: itemNodeTransition)
            paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -spacing / 2.0, bottom: 0.0, right: -spacing / 2.0)
                        
            leftOffset += paneNodeSize.width + spacing
        }
        leftOffset -= spacing
        leftOffset += resolvedSideInset
        
        self.scrollNode.view.contentSize = CGSize(width: leftOffset, height: size.height)
    }
}
