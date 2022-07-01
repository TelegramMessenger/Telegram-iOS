import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import MultiAnimationRenderer
import AnimationCache
import AccountContext
import LottieAnimationCache
import VideoAnimationCache
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import ShimmerEffect
import PagerComponent
import StickerResources
import AppBundle
import ContextUI
import PremiumUI
import StickerPackPreviewUI
import UndoUI

private let premiumBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat List/PeerPremiumIcon"), color: .white)

private final class PremiumBadgeView: UIView {
    private let iconLayer: SimpleLayer
    
    init() {
        self.iconLayer = SimpleLayer()
        self.iconLayer.contents = premiumBadgeIcon?.cgImage
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.iconLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(backgroundColor: UIColor, size: CGSize) {
        //self.updateColor(color: backgroundColor, transition: .immediate)
        self.backgroundColor = backgroundColor
        self.layer.cornerRadius = size.width / 2.0
        
        self.iconLayer.frame = CGRect(origin: CGPoint(), size: size).insetBy(dx: 2.0, dy: 2.0)
        
        //super.update(size: size, cornerRadius: min(size.width / 2.0, size.height / 2.0), transition: .immediate)
    }
}

public final class EmojiPagerContentComponent: Component {
    public typealias EnvironmentType = (EntityKeyboardChildEnvironment, PagerComponentChildEnvironment)
    
    public final class InputInteraction {
        public let performItemAction: (Item, UIView, CGRect, CALayer) -> Void
        public let deleteBackwards: () -> Void
        public let openStickerSettings: () -> Void
        public let pushController: (ViewController) -> Void
        public let presentController: (ViewController) -> Void
        public let presentGlobalOverlayController: (ViewController) -> Void
        public let navigationController: () -> NavigationController?
        public let sendSticker: ((FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?) -> Void)?
        public let chatPeerId: PeerId?
        
        public init(
            performItemAction: @escaping (Item, UIView, CGRect, CALayer) -> Void,
            deleteBackwards: @escaping () -> Void,
            openStickerSettings: @escaping () -> Void,
            pushController: @escaping (ViewController) -> Void,
            presentController: @escaping (ViewController) -> Void,
            presentGlobalOverlayController: @escaping (ViewController) -> Void,
            navigationController: @escaping () -> NavigationController?,
            sendSticker: ((FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?) -> Void)?,
            chatPeerId: PeerId?
        ) {
            self.performItemAction = performItemAction
            self.deleteBackwards = deleteBackwards
            self.openStickerSettings = openStickerSettings
            self.pushController = pushController
            self.presentController = presentController
            self.presentGlobalOverlayController = presentGlobalOverlayController
            self.navigationController = navigationController
            self.sendSticker = sendSticker
            self.chatPeerId = chatPeerId
        }
    }
    
    public final class Item: Equatable {
        public let emoji: String
        public let file: TelegramMediaFile
        public let stickerPackItem: StickerPackItem?
        
        public init(emoji: String, file: TelegramMediaFile, stickerPackItem: StickerPackItem?) {
            self.emoji = emoji
            self.file = file
            self.stickerPackItem = stickerPackItem
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.emoji != rhs.emoji {
                return false
            }
            if lhs.file.fileId != rhs.file.fileId {
                return false
            }
            if lhs.stickerPackItem?.file.fileId != rhs.stickerPackItem?.file.fileId {
                return false
            }
            
            return true
        }
    }
    
    public final class ItemGroup: Equatable {
        public let id: AnyHashable
        public let title: String?
        public let items: [Item]
        
        public init(
            id: AnyHashable,
            title: String?,
            items: [Item]
        ) {
            self.id = id
            self.title = title
            self.items = items
        }
        
        public static func ==(lhs: ItemGroup, rhs: ItemGroup) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.items != rhs.items {
                return false
            }
            return true
        }
    }
    
    public enum ItemLayoutType {
        case compact
        case detailed
    }
    
    public let id: AnyHashable
    public let context: AccountContext
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer
    public let inputInteraction: InputInteraction
    public let itemGroups: [ItemGroup]
    public let itemLayoutType: ItemLayoutType
    
    public init(
        id: AnyHashable,
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        inputInteraction: InputInteraction,
        itemGroups: [ItemGroup],
        itemLayoutType: ItemLayoutType
    ) {
        self.id = id
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.inputInteraction = inputInteraction
        self.itemGroups = itemGroups
        self.itemLayoutType = itemLayoutType
    }
    
    public static func ==(lhs: EmojiPagerContentComponent, rhs: EmojiPagerContentComponent) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.animationCache !== rhs.animationCache {
            return false
        }
        if lhs.animationRenderer !== rhs.animationRenderer {
            return false
        }
        if lhs.inputInteraction !== rhs.inputInteraction {
            return false
        }
        if lhs.itemGroups != rhs.itemGroups {
            return false
        }
        if lhs.itemLayoutType != rhs.itemLayoutType {
            return false
        }
        
        return true
    }
    
    public final class Tag {
        public let id: AnyHashable
        
        public init(id: AnyHashable) {
            self.id = id
        }
    }
    
    public final class View: UIView, UIScrollViewDelegate, ComponentTaggedView {
        private struct ItemGroupDescription: Equatable {
            let id: AnyHashable
            let hasTitle: Bool
            let itemCount: Int
        }
        
        private struct ItemGroupLayout: Equatable {
            let frame: CGRect
            let id: AnyHashable
            let itemTopOffset: CGFloat
            let itemCount: Int
        }
        
        private struct ItemLayout: Equatable {
            var width: CGFloat
            var containerInsets: UIEdgeInsets
            var itemGroupLayouts: [ItemGroupLayout]
            var itemSize: CGFloat
            var horizontalSpacing: CGFloat
            var verticalSpacing: CGFloat
            var verticalGroupSpacing: CGFloat
            var itemsPerRow: Int
            var contentSize: CGSize
            
            init(width: CGFloat, containerInsets: UIEdgeInsets, itemGroups: [ItemGroupDescription], itemLayoutType: ItemLayoutType) {
                self.width = width
                self.containerInsets = containerInsets
                
                let minSpacing: CGFloat
                switch itemLayoutType {
                case .compact:
                    self.itemSize = 36.0
                    self.verticalSpacing = 9.0
                    minSpacing = 9.0
                case .detailed:
                    self.itemSize = 76.0
                    self.verticalSpacing = 2.0
                    minSpacing = 2.0
                }
                
                self.verticalGroupSpacing = 18.0
                
                let itemHorizontalSpace = width - self.containerInsets.left - self.containerInsets.right
                
                self.itemsPerRow = Int((itemHorizontalSpace + minSpacing) / (self.itemSize + minSpacing))
                self.horizontalSpacing = floor((itemHorizontalSpace - self.itemSize * CGFloat(self.itemsPerRow)) / CGFloat(self.itemsPerRow - 1))
                
                var verticalGroupOrigin: CGFloat = self.containerInsets.top
                self.itemGroupLayouts = []
                for itemGroup in itemGroups {
                    var itemTopOffset: CGFloat = 0.0
                    if itemGroup.hasTitle {
                        itemTopOffset += 24.0
                    }
                    
                    let numRowsInGroup = (itemGroup.itemCount + (self.itemsPerRow - 1)) / self.itemsPerRow
                    let groupContentSize = CGSize(width: width, height: itemTopOffset + CGFloat(numRowsInGroup) * self.itemSize + CGFloat(max(0, numRowsInGroup - 1)) * self.verticalSpacing)
                    self.itemGroupLayouts.append(ItemGroupLayout(
                        frame: CGRect(origin: CGPoint(x: 0.0, y: verticalGroupOrigin), size: groupContentSize),
                        id: itemGroup.id,
                        itemTopOffset: itemTopOffset,
                        itemCount: itemGroup.itemCount
                    ))
                    verticalGroupOrigin += groupContentSize.height + self.verticalGroupSpacing
                }
                verticalGroupOrigin += self.containerInsets.bottom
                self.contentSize = CGSize(width: width, height: verticalGroupOrigin)
            }
            
            func frame(groupIndex: Int, itemIndex: Int) -> CGRect {
                let groupLayout = self.itemGroupLayouts[groupIndex]
                
                let row = itemIndex / self.itemsPerRow
                let column = itemIndex % self.itemsPerRow
                
                return CGRect(
                    origin: CGPoint(
                        x: self.containerInsets.left + CGFloat(column) * (self.itemSize + self.horizontalSpacing),
                        y: groupLayout.frame.minY + groupLayout.itemTopOffset + CGFloat(row) * (self.itemSize + self.verticalSpacing)
                    ),
                    size: CGSize(
                        width: self.itemSize,
                        height: self.itemSize
                    )
                )
            }
            
            func visibleItems(for rect: CGRect) -> [(id: AnyHashable, groupIndex: Int, groupItems: Range<Int>)] {
                var result: [(id: AnyHashable, groupIndex: Int, groupItems: Range<Int>)] = []
                
                for groupIndex in 0 ..< self.itemGroupLayouts.count {
                    let group = self.itemGroupLayouts[groupIndex]
                    
                    if !rect.intersects(group.frame) {
                        continue
                    }
                    let offsetRect = rect.offsetBy(dx: -self.containerInsets.left, dy: -group.frame.minY - group.itemTopOffset)
                    var minVisibleRow = Int(floor((offsetRect.minY - self.verticalSpacing) / (self.itemSize + self.verticalSpacing)))
                    minVisibleRow = max(0, minVisibleRow)
                    let maxVisibleRow = Int(ceil((offsetRect.maxY - self.verticalSpacing) / (self.itemSize + self.verticalSpacing)))

                    let minVisibleIndex = minVisibleRow * self.itemsPerRow
                    let maxVisibleIndex = min(group.itemCount - 1, (maxVisibleRow + 1) * self.itemsPerRow - 1)
                    
                    if maxVisibleIndex >= minVisibleIndex {
                        result.append((
                            id: group.id,
                            groupIndex: groupIndex,
                            groupItems: minVisibleIndex ..< (maxVisibleIndex + 1)
                        ))
                    }
                }
                
                return result
            }
        }
        
        final class ItemLayer: MultiAnimationRenderTarget {
            struct Key: Hashable {
                var groupId: AnyHashable
                var fileId: MediaId
            }
            
            let item: Item
            
            private let file: TelegramMediaFile
            private let placeholderColor: UIColor
            private let size: CGSize
            private var disposable: Disposable?
            private var fetchDisposable: Disposable?
            private var premiumBadgeView: PremiumBadgeView?
            
            private var isInHierarchyValue: Bool = false
            public var isVisibleForAnimations: Bool = false {
                didSet {
                    if self.isVisibleForAnimations != oldValue {
                        self.updatePlayback()
                    }
                }
            }
            private var displayPlaceholder: Bool = false
            
            init(
                item: Item,
                context: AccountContext,
                groupId: String,
                attemptSynchronousLoad: Bool,
                file: TelegramMediaFile,
                cache: AnimationCache,
                renderer: MultiAnimationRenderer,
                placeholderColor: UIColor,
                blurredBadgeColor: UIColor,
                displayPremiumBadgeIfAvailable: Bool,
                pointSize: CGSize
            ) {
                self.item = item
                self.file = file
                self.placeholderColor = placeholderColor
                
                let scale = min(2.0, UIScreenScale)
                let pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
                self.size = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
                
                super.init()
                
                if file.isAnimatedSticker || file.isVideoSticker {
                    let loadAnimation: () -> Void = { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.disposable = renderer.add(groupId: groupId, target: strongSelf, cache: cache, itemId: file.resource.id.stringRepresentation, size: pixelSize, fetch: { size, writer in
                            let source = AnimatedStickerResourceSource(account: context.account, resource: file.resource, fitzModifier: nil, isVideo: false)
                            
                            let dataDisposable = source.directDataPath(attemptSynchronously: false).start(next: { result in
                                guard let result = result else {
                                    return
                                }
                                
                                if file.isVideoSticker {
                                    cacheVideoAnimation(path: result, width: Int(size.width), height: Int(size.height), writer: writer)
                                } else {
                                    guard let data = try? Data(contentsOf: URL(fileURLWithPath: result)) else {
                                        writer.finish()
                                        return
                                    }
                                    cacheLottieAnimation(data: data, width: Int(size.width), height: Int(size.height), writer: writer)
                                }
                            })
                            
                            let fetchDisposable = freeMediaFileResourceInteractiveFetched(account: context.account, fileReference: stickerPackFileReference(file), resource: file.resource).start()
                            
                            return ActionDisposable {
                                dataDisposable.dispose()
                                fetchDisposable.dispose()
                            }
                        })
                    }
                    
                    if attemptSynchronousLoad {
                        if !renderer.loadFirstFrameSynchronously(groupId: groupId, target: self, cache: cache, itemId: file.resource.id.stringRepresentation, size: pixelSize) {
                            self.displayPlaceholder = true
                            
                            if let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: self.size, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: placeholderColor) {
                                self.contents = image.cgImage
                            }
                        }
                        
                        loadAnimation()
                    } else {
                        let _ = renderer.loadFirstFrame(groupId: groupId, target: self, cache: cache, itemId: file.resource.id.stringRepresentation, size: pixelSize, completion: { _ in
                            loadAnimation()
                        })
                    }
                } else if let dimensions = file.dimensions {
                    let isSmall: Bool = false
                    self.disposable = (chatMessageSticker(account: context.account, file: file, small: isSmall, synchronousLoad: attemptSynchronousLoad)).start(next: { [weak self] resultTransform in
                        let boundingSize = CGSize(width: 93.0, height: 93.0)
                        let imageSize = dimensions.cgSize.aspectFilled(boundingSize)
                        
                        if let image = resultTransform(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), resizeMode: .fill(.clear)))?.generateImage() {
                            Queue.mainQueue().async {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.contents = image.cgImage
                            }
                        }
                    })
                    
                    self.fetchDisposable = freeMediaFileResourceInteractiveFetched(account: context.account, fileReference: stickerPackFileReference(file), resource: chatMessageStickerResource(file: file, small: isSmall)).start()
                }
                
                if displayPremiumBadgeIfAvailable && file.isPremiumSticker {
                    let premiumBadgeView = PremiumBadgeView()
                    let badgeSize = CGSize(width: 20.0, height: 20.0)
                    premiumBadgeView.frame = CGRect(origin: CGPoint(x: pointSize.width - badgeSize.width, y: pointSize.height - badgeSize.height), size: badgeSize)
                    premiumBadgeView.update(backgroundColor: blurredBadgeColor, size: badgeSize)
                    self.premiumBadgeView = premiumBadgeView
                    self.addSublayer(premiumBadgeView.layer)
                }
            }
            
            override public init(layer: Any) {
                preconditionFailure()
            }
            
            required public init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            deinit {
                self.disposable?.dispose()
                self.fetchDisposable?.dispose()
            }
            
            override public func action(forKey event: String) -> CAAction? {
                if event == kCAOnOrderIn {
                    self.isInHierarchyValue = true
                } else if event == kCAOnOrderOut {
                    self.isInHierarchyValue = false
                }
                self.updatePlayback()
                return nullAction
            }
            
            private func updatePlayback() {
                let shouldBePlaying = self.isInHierarchyValue && self.isVisibleForAnimations
                
                self.shouldBeAnimating = shouldBePlaying
            }
            
            override func updateDisplayPlaceholder(displayPlaceholder: Bool) {
                if self.displayPlaceholder == displayPlaceholder {
                    return
                }
                
                self.displayPlaceholder = displayPlaceholder
                let file = self.file
                let size = self.size
                let placeholderColor = self.placeholderColor
                
                Queue.concurrentDefaultQueue().async { [weak self] in
                    if let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: size, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: placeholderColor) {
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if strongSelf.displayPlaceholder {
                                strongSelf.contents = image.cgImage
                            }
                        }
                    }
                }
            }
        }
        
        private final class ContentScrollView: UIScrollView, PagerExpandableScrollView {
        }
        
        private let scrollView: ContentScrollView
        
        private var visibleItemLayers: [ItemLayer.Key: ItemLayer] = [:]
        private var visibleGroupHeaders: [AnyHashable: ComponentView<Empty>] = [:]
        private var ignoreScrolling: Bool = false
        
        private var component: EmojiPagerContentComponent?
        private var pagerEnvironment: PagerComponentChildEnvironment?
        private var theme: PresentationTheme?
        private var activeItemUpdated: ActionSlot<(AnyHashable, Transition)>?
        private var itemLayout: ItemLayout?
        
        private var currentContextGestureItemKey: ItemLayer.Key?
        
        private weak var peekController: PeekController?
        
        override init(frame: CGRect) {
            self.scrollView = ContentScrollView()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
            /*self.useSublayerTransformForActivation = false
            self.shouldBegin = { [weak self] point in
                guard let strongSelf = self else {
                    return false
                }
                if let item = strongSelf.item(atPoint: point), let itemLayer = strongSelf.visibleItemLayers[item.1] {
                    strongSelf.currentContextGestureItemKey = item.1
                    strongSelf.targetLayerForActivationProgress = itemLayer
                    return true
                } else {
                    return false
                }
            }
            self.contextGesture?.cancelGesturesOnActivation = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.scrollView.panGestureRecognizer.state = .failed
            }*/
            
            let peekRecognizer = PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
                guard let strongSelf = self, let component = strongSelf.component else {
                    return nil
                }
                guard let item = strongSelf.item(atPoint: point), let itemLayer = strongSelf.visibleItemLayers[item.1] else {
                    return nil
                }
                
                let context = component.context
                let accountPeerId = context.account.peerId
                return combineLatest(
                    context.engine.stickers.isStickerSaved(id: item.0.file.fileId),
                    context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountPeerId)) |> map { peer -> Bool in
                        var hasPremium = false
                        if case let .user(user) = peer, user.isPremium {
                            hasPremium = true
                        }
                        return hasPremium
                    }
                )
                |> deliverOnMainQueue
                |> map { [weak itemLayer] isStarred, hasPremium -> (UIView, CGRect, PeekControllerContent)? in
                    guard let strongSelf = self, let component = strongSelf.component, let itemLayer = itemLayer else {
                        return nil
                    }
                    var menuItems: [ContextMenuItem] = []
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    
                    if let sendSticker = component.inputInteraction.sendSticker, let chatPeerId = component.inputInteraction.chatPeerId {
                        if chatPeerId != component.context.account.peerId && chatPeerId.namespace != Namespaces.Peer.SecretChat  {
                            menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                if let strongSelf = self, let peekController = strongSelf.peekController {
                                    if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                        sendSticker(.standalone(media: item.0.file), true, false, nil, false, animationNode.view, animationNode.bounds, nil)
                                    } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                        sendSticker(.standalone(media: item.0.file), true, false, nil, false, imageNode.view, imageNode.bounds, nil)
                                    }
                                }
                                f(.default)
                            })))
                        }
                    
                        menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            if let strongSelf = self, let peekController = strongSelf.peekController {
                                if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                    let _ = sendSticker(.standalone(media: item.0.file), false, true, nil, false, animationNode.view, animationNode.bounds, nil)
                                } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                    let _ = sendSticker(.standalone(media: item.0.file), false, true, nil, false, imageNode.view, imageNode.bounds, nil)
                                }
                            }
                            f(.default)
                        })))
                    }
                    
                    menuItems.append(
                        .action(ContextMenuActionItem(text: isStarred ? presentationData.strings.Stickers_RemoveFromFavorites : presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                            f(.default)
                            
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let _ = (context.engine.stickers.toggleStickerSaved(file: item.0.file, saved: !isStarred)
                            |> deliverOnMainQueue).start(next: { result in
                                switch result {
                                case .generic:
                                    component.inputInteraction.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: item.0.file, title: nil, text: !isStarred ? presentationData.strings.Conversation_StickerAddedToFavorites : presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil), elevatedLayout: false, action: { _ in return false }))
                                case let .limitExceeded(limit, premiumLimit):
                                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                    let text: String
                                    if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                        text = presentationData.strings.Premium_MaxFavedStickersFinalText
                                    } else {
                                        text = presentationData.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
                                    }
                                    component.inputInteraction.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: item.0.file, title: presentationData.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil), elevatedLayout: false, action: { action in
                                        if case .info = action {
                                            let controller = PremiumIntroScreen(context: context, source: .savedStickers)
                                            component.inputInteraction.pushController(controller)
                                            return true
                                        }
                                        return false
                                    }))
                                }
                            })
                        }))
                    )
                    menuItems.append(
                        .action(ContextMenuActionItem(text: presentationData.strings.StickerPack_ViewPack, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            f(.default)
                            
                            loop: for attribute in item.0.file.attributes {
                            switch attribute {
                            case let .Sticker(_, packReference, _):
                                if let packReference = packReference {
                                    let controller = StickerPackScreen(context: context, updatedPresentationData: nil, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: component.inputInteraction.navigationController(), sendSticker: { file, sourceView, sourceRect in
                                        //return component.inputInteraction.sendSticker(file, false, false, nil, false, sourceNode, sourceRect, nil)
                                        return false
                                    })
                                    
                                    component.inputInteraction.navigationController()?.view.window?.endEditing(true)
                                    component.inputInteraction.presentController(controller)
                                }
                                break loop
                            default:
                                break
                            }
                        }
                        }))
                    )
                    
                    return (strongSelf, strongSelf.scrollView.convert(itemLayer.frame, to: strongSelf), StickerPreviewPeekContent(account: context.account, theme: presentationData.theme, strings: presentationData.strings, item: .pack(item.0.file), isLocked: item.0.file.isPremiumSticker && !hasPremium, menu: menuItems, openPremiumIntro: {
                        let controller = PremiumIntroScreen(context: context, source: .stickers)
                        component.inputInteraction.pushController(controller)
                    }))
                }
            }, present: { [weak self] content, sourceView, sourceRect in
                guard let strongSelf = self, let component = strongSelf.component else {
                    return nil
                }
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let controller = PeekController(presentationData: presentationData, content: content, sourceView: {
                    return (sourceView, sourceRect)
                })
                /*controller.visibilityUpdated = { [weak self] visible in
                    self?.previewingStickersPromise.set(visible)
                    self?.requestDisableStickerAnimations?(visible)
                    self?.simulateUpdateLayout(isVisible: !visible)
                }*/
                strongSelf.peekController = controller
                component.inputInteraction.presentGlobalOverlayController(controller)
                return controller
            }, updateContent: { [weak self] content in
                guard let strongSelf = self else {
                    return
                }
                
                let _ = strongSelf
                
                /*var item: StickerPreviewPeekItem?
                if let content = content as? StickerPreviewPeekContent {
                    item = content.item
                }
                strongSelf.updatePreviewingItem(item: item, animated: true)*/
            })
            self.addGestureRecognizer(peekRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func matches(tag: Any) -> Bool {
            if let tag = tag as? Tag {
                if tag.id == self.component?.id {
                    return true
                }
            }
            return false
        }
        
        public func scrollToItemGroup(groupId: AnyHashable) {
            guard let itemLayout = self.itemLayout else {
                return
            }
            for group in itemLayout.itemGroupLayouts {
                if group.id == groupId {
                    let wasIgnoringScrollingEvents = self.ignoreScrolling
                    self.ignoreScrolling = true
                    self.scrollView.setContentOffset(self.scrollView.contentOffset, animated: false)
                    self.ignoreScrolling = wasIgnoringScrollingEvents
                    
                    self.scrollView.scrollRectToVisible(CGRect(origin: group.frame.origin.offsetBy(dx: 0.0, dy: floor(-itemLayout.verticalGroupSpacing / 2.0)), size: CGSize(width: 1.0, height: self.scrollView.bounds.height)), animated: true)
                }
            }
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                if let component = self.component, let (item, itemKey) = self.item(atPoint: recognizer.location(in: self)), let itemLayer = self.visibleItemLayers[itemKey] {
                    component.inputInteraction.performItemAction(item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer)
                }
            }
        }
        
        private func item(atPoint point: CGPoint) -> (Item, ItemLayer.Key)? {
            let localPoint = self.convert(point, to: self.scrollView)
            
            for (key, itemLayer) in self.visibleItemLayers {
                if itemLayer.frame.contains(localPoint) {
                    return (itemLayer.item, key)
                }
            }
            
            return nil
        }
        
        private struct ScrollingOffsetState: Equatable {
            var value: CGFloat
            var isDraggingOrDecelerating: Bool
        }
        
        private var previousScrollingOffset: ScrollingOffsetState?
        
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            if let presentation = scrollView.layer.presentation() {
                scrollView.bounds = presentation.bounds
                scrollView.layer.removeAllAnimations()
            }
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            
            self.updateVisibleItems(attemptSynchronousLoads: false)
            
            self.updateScrollingOffset(transition: .immediate)
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if velocity.y != 0.0 {
                targetContentOffset.pointee.y = self.snappedContentOffset(proposedOffset: targetContentOffset.pointee.y)
            }
        }
        
        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                self.snapScrollingOffsetToInsets()
            }
        }
        
        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            self.snapScrollingOffsetToInsets()
        }
        
        private func updateScrollingOffset(transition: Transition) {
            let isInteracting = scrollView.isDragging || scrollView.isDecelerating
            if let previousScrollingOffsetValue = self.previousScrollingOffset {
                let currentBounds = scrollView.bounds
                let offsetToTopEdge = max(0.0, currentBounds.minY - 0.0)
                let offsetToBottomEdge = max(0.0, scrollView.contentSize.height - currentBounds.maxY)
                
                let relativeOffset = scrollView.contentOffset.y - previousScrollingOffsetValue.value
                self.pagerEnvironment?.onChildScrollingUpdate(PagerComponentChildEnvironment.ContentScrollingUpdate(
                    relativeOffset: relativeOffset,
                    absoluteOffsetToTopEdge: offsetToTopEdge,
                    absoluteOffsetToBottomEdge: offsetToBottomEdge,
                    isInteracting: isInteracting,
                    transition: transition
                ))
            }
            self.previousScrollingOffset = ScrollingOffsetState(value: scrollView.contentOffset.y, isDraggingOrDecelerating: isInteracting)
        }
        
        private func snappedContentOffset(proposedOffset: CGFloat) -> CGFloat {
            guard let pagerEnvironment = self.pagerEnvironment else {
                return proposedOffset
            }
            
            var proposedOffset = proposedOffset
            let bounds = self.bounds
            if proposedOffset + bounds.height > self.scrollView.contentSize.height - pagerEnvironment.containerInsets.bottom {
                proposedOffset = self.scrollView.contentSize.height - bounds.height
            }
            if proposedOffset < pagerEnvironment.containerInsets.top {
                proposedOffset = 0.0
            }
            
            return proposedOffset
        }
        
        private func snapScrollingOffsetToInsets() {
            let transition = Transition(animation: .curve(duration: 0.4, curve: .spring))
            
            var currentBounds = self.scrollView.bounds
            currentBounds.origin.y = self.snappedContentOffset(proposedOffset: currentBounds.minY)
            transition.setBounds(view: self.scrollView, bounds: currentBounds)
            
            self.updateScrollingOffset(transition: transition)
        }
        
        private func updateVisibleItems(attemptSynchronousLoads: Bool) {
            guard let component = self.component, let theme = self.theme, let itemLayout = self.itemLayout else {
                return
            }
            
            var topVisibleGroupId: AnyHashable?
            
            var validIds = Set<ItemLayer.Key>()
            var validGroupHeaderIds = Set<AnyHashable>()
            
            for groupItems in itemLayout.visibleItems(for: self.scrollView.bounds) {
                if topVisibleGroupId == nil {
                    topVisibleGroupId = groupItems.id
                }
                
                let itemGroup = component.itemGroups[groupItems.groupIndex]
                let itemGroupLayout = itemLayout.itemGroupLayouts[groupItems.groupIndex]
                
                if let title = itemGroup.title {
                    validGroupHeaderIds.insert(itemGroup.id)
                    let groupHeaderView: ComponentView<Empty>
                    if let current = self.visibleGroupHeaders[itemGroup.id] {
                        groupHeaderView = current
                    } else {
                        groupHeaderView = ComponentView<Empty>()
                        self.visibleGroupHeaders[itemGroup.id] = groupHeaderView
                    }
                    let groupHeaderSize = groupHeaderView.update(
                        transition: .immediate,
                        component: AnyComponent(Text(
                            text: title, font: Font.medium(12.0), color: theme.chat.inputMediaPanel.stickersSectionTextColor
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.contentSize.width - itemLayout.containerInsets.left - itemLayout.containerInsets.right, height: 100.0)
                    )
                    if let view = groupHeaderView.view {
                        if view.superview == nil {
                            self.scrollView.addSubview(view)
                        }
                        view.frame = CGRect(origin: CGPoint(x: itemLayout.containerInsets.left, y: itemGroupLayout.frame.minY + 1.0), size: groupHeaderSize)
                    }
                }
                
                for index in groupItems.groupItems.lowerBound ..< groupItems.groupItems.upperBound {
                    let item = itemGroup.items[index]
                    let itemId = ItemLayer.Key(groupId: itemGroup.id, fileId: item.file.fileId)
                    validIds.insert(itemId)
                    
                    let itemLayer: ItemLayer
                    if let current = self.visibleItemLayers[itemId] {
                        itemLayer = current
                    } else {
                        itemLayer = ItemLayer(
                            item: item,
                            context: component.context,
                            groupId: "keyboard-\(Int(itemLayout.itemSize))",
                            attemptSynchronousLoad: attemptSynchronousLoads,
                            file: item.file,
                            cache: component.animationCache,
                            renderer: component.animationRenderer,
                            placeholderColor: theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.1),
                            blurredBadgeColor: theme.chat.inputPanel.panelBackgroundColor.withMultipliedAlpha(0.5),
                            displayPremiumBadgeIfAvailable: true,
                            pointSize: CGSize(width: itemLayout.itemSize, height: itemLayout.itemSize)
                        )
                        self.scrollView.layer.addSublayer(itemLayer)
                        self.visibleItemLayers[itemId] = itemLayer
                    }
                    
                    let itemFrame = itemLayout.frame(groupIndex: groupItems.groupIndex, itemIndex: index)
                    itemLayer.position = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                    itemLayer.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                    itemLayer.isVisibleForAnimations = true
                }
            }

            var removedIds: [ItemLayer.Key] = []
            for (id, itemLayer) in self.visibleItemLayers {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    itemLayer.removeFromSuperlayer()
                }
            }
            for id in removedIds {
                self.visibleItemLayers.removeValue(forKey: id)
            }
            
            var removedGroupHeaderIds: [AnyHashable] = []
            for (id, groupHeaderView) in self.visibleGroupHeaders {
                if !validGroupHeaderIds.contains(id) {
                    removedGroupHeaderIds.append(id)
                    groupHeaderView.view?.removeFromSuperview()
                }
            }
            for id in removedGroupHeaderIds {
                self.visibleGroupHeaders.removeValue(forKey: id)
            }
            
            if let topVisibleGroupId = topVisibleGroupId {
                self.activeItemUpdated?.invoke((topVisibleGroupId, .immediate))
            }
        }
        
        func update(component: EmojiPagerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.theme = environment[EntityKeyboardChildEnvironment.self].value.theme
            self.activeItemUpdated = environment[EntityKeyboardChildEnvironment.self].value.getContentActiveItemUpdated(component.id)
            
            let pagerEnvironment = environment[PagerComponentChildEnvironment.self].value
            self.pagerEnvironment = pagerEnvironment
            
            var itemGroups: [ItemGroupDescription] = []
            for itemGroup in component.itemGroups {
                itemGroups.append(ItemGroupDescription(
                    id: itemGroup.id,
                    hasTitle: itemGroup.title != nil,
                    itemCount: itemGroup.items.count
                ))
            }
            
            let itemLayout = ItemLayout(width: availableSize.width, containerInsets: UIEdgeInsets(top: pagerEnvironment.containerInsets.top + 9.0, left: pagerEnvironment.containerInsets.left + 12.0, bottom: 9.0 + pagerEnvironment.containerInsets.bottom, right: pagerEnvironment.containerInsets.right + 12.0), itemGroups: itemGroups, itemLayoutType: component.itemLayoutType)
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            if self.scrollView.scrollIndicatorInsets != pagerEnvironment.containerInsets {
                self.scrollView.scrollIndicatorInsets = pagerEnvironment.containerInsets
            }
            self.previousScrollingOffset = ScrollingOffsetState(value: scrollView.contentOffset.y, isDraggingOrDecelerating: scrollView.isDragging || scrollView.isDecelerating)
            self.ignoreScrolling = false
            
            self.updateVisibleItems(attemptSynchronousLoads: true)
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
