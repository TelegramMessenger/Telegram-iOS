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
import StickerPeekUI
import UndoUI
import AudioToolbox
import SolidRoundedButtonComponent

private let premiumBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat List/PeerPremiumIcon"), color: .white)
private let featuredBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/PanelBadgeAdd"), color: .white)
private let lockedBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/PanelBadgeLock"), color: .white)

private final class PremiumBadgeView: UIView {
    private var badge: EmojiPagerContentComponent.View.ItemLayer.Badge?
    
    let contentLayer: SimpleLayer
    private let overlayColorLayer: SimpleLayer
    private let iconLayer: SimpleLayer
    
    init() {
        self.contentLayer = SimpleLayer()
        self.contentLayer.contentsGravity = .resize
        self.contentLayer.masksToBounds = true
        
        self.overlayColorLayer = SimpleLayer()
        self.overlayColorLayer.masksToBounds = true
        
        self.iconLayer = SimpleLayer()
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.contentLayer)
        self.layer.addSublayer(self.overlayColorLayer)
        self.layer.addSublayer(self.iconLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(transition: Transition, badge: EmojiPagerContentComponent.View.ItemLayer.Badge, backgroundColor: UIColor, size: CGSize) {
        if self.badge != badge {
            self.badge = badge
            
            switch badge {
            case .premium:
                self.iconLayer.contents = premiumBadgeIcon?.cgImage
            case .featured:
                self.iconLayer.contents = featuredBadgeIcon?.cgImage
            case .locked:
                self.iconLayer.contents = lockedBadgeIcon?.cgImage
            }
        }
        
        let iconInset: CGFloat
        switch badge {
        case .premium:
            iconInset = 2.0
        case .featured:
            iconInset = 0.0
        case .locked:
            iconInset = 0.0
        }
        
        self.overlayColorLayer.backgroundColor = backgroundColor.cgColor
        
        transition.setFrame(layer: self.contentLayer, frame: CGRect(origin: CGPoint(), size: size))
        transition.setCornerRadius(layer: self.contentLayer, cornerRadius: min(size.width / 2.0, size.height / 2.0))
        
        transition.setFrame(layer: self.overlayColorLayer, frame: CGRect(origin: CGPoint(), size: size))
        transition.setCornerRadius(layer: self.overlayColorLayer, cornerRadius: min(size.width / 2.0, size.height / 2.0))
        
        transition.setFrame(layer: self.iconLayer, frame: CGRect(origin: CGPoint(), size: size).insetBy(dx: iconInset, dy: iconInset))
    }
}

private final class GroupHeaderLayer: SimpleLayer {
    private let textLayer: SimpleLayer
    private var lockIconLayer: SimpleLayer?
    private(set) var clearIconLayer: SimpleLayer?
    
    private var theme: PresentationTheme?
    
    private var currentTextLayout: (string: String, color: UIColor, constrainedWidth: CGFloat, size: CGSize)?
    
    override init() {
        self.textLayer = SimpleLayer()
        
        super.init()
        
        self.addSublayer(self.textLayer)
    }
    
    override init(layer: Any) {
        self.textLayer = SimpleLayer()
        
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(theme: PresentationTheme, title: String, isPremiumLocked: Bool, hasClear: Bool, constrainedWidth: CGFloat) -> CGSize {
        var themeUpdated = false
        if self.theme !== theme {
            self.theme = theme
            themeUpdated = true
        }
        
        let color = theme.chat.inputMediaPanel.stickersSectionTextColor
        
        let titleHorizontalOffset: CGFloat
        if isPremiumLocked {
            let lockIconLayer: SimpleLayer
            if let current = self.lockIconLayer {
                lockIconLayer = current
            } else {
                lockIconLayer = SimpleLayer()
                self.lockIconLayer = lockIconLayer
                self.addSublayer(lockIconLayer)
            }
            if let image = PresentationResourcesChat.chatEntityKeyboardLock(theme) {
                let imageSize = image.size.aspectFitted(CGSize(width: 16.0, height: 16.0))
                lockIconLayer.contents = image.cgImage
                titleHorizontalOffset = imageSize.width + 2.0
                lockIconLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: imageSize)
            } else {
                lockIconLayer.contents = nil
                titleHorizontalOffset = 0.0
            }
        } else {
            if let lockIconLayer = self.lockIconLayer {
                self.lockIconLayer = nil
                lockIconLayer.removeFromSuperlayer()
            }
            titleHorizontalOffset = 0.0
        }
        
        let textConstrainedWidth = constrainedWidth - titleHorizontalOffset - 10.0
        
        let textSize: CGSize
        if let currentTextLayout = self.currentTextLayout, currentTextLayout.string == title, currentTextLayout.color == color, currentTextLayout.constrainedWidth == textConstrainedWidth {
            textSize = currentTextLayout.size
        } else {
            let string = NSAttributedString(string: title.uppercased(), font: Font.medium(12.0), textColor: color)
            let stringBounds = string.boundingRect(with: CGSize(width: textConstrainedWidth, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
            textSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
            self.textLayer.contents = generateImage(textSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                string.draw(in: stringBounds)
                
                UIGraphicsPopContext()
            })?.cgImage
            self.currentTextLayout = (title, color, textConstrainedWidth, textSize)
        }
        
        self.textLayer.frame = CGRect(origin: CGPoint(x: titleHorizontalOffset, y: 0.0), size: textSize)
        
        var clearWidth: CGFloat = 0.0
        if hasClear {
            let clearIconLayer: SimpleLayer
            var updateImage = themeUpdated
            if let current = self.clearIconLayer {
                clearIconLayer = current
            } else {
                updateImage = true
                clearIconLayer = SimpleLayer()
                self.clearIconLayer = clearIconLayer
                self.addSublayer(clearIconLayer)
            }
            var clearSize = clearIconLayer.bounds.size
            if updateImage, let image = PresentationResourcesChat.chatInputMediaPanelGridDismissImage(theme) {
                clearSize = image.size
                clearSize.width = 10.0
                clearSize.height = 10.0
                clearIconLayer.contents = image.cgImage
            }
            
            clearIconLayer.frame = CGRect(origin: CGPoint(x: titleHorizontalOffset + textSize.width + 4.0, y: floorToScreenPixels((textSize.height - clearSize.height) / 2.0)), size: clearSize)
            clearWidth = 4.0 + clearSize.width
        }
        
        return CGSize(width: titleHorizontalOffset + textSize.width + clearWidth, height: textSize.height)
    }
}

public final class EmojiPagerContentComponent: Component {
    public typealias EnvironmentType = (EntityKeyboardChildEnvironment, PagerComponentChildEnvironment)
    
    public final class InputInteraction {
        public let performItemAction: (Item, UIView, CGRect, CALayer) -> Void
        public let deleteBackwards: () -> Void
        public let openStickerSettings: () -> Void
        public let addGroupAction: (AnyHashable, Bool) -> Void
        public let clearGroup: (AnyHashable) -> Void
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
            addGroupAction: @escaping (AnyHashable, Bool) -> Void,
            clearGroup: @escaping (AnyHashable) -> Void,
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
            self.addGroupAction = addGroupAction
            self.clearGroup = clearGroup
            self.pushController = pushController
            self.presentController = presentController
            self.presentGlobalOverlayController = presentGlobalOverlayController
            self.navigationController = navigationController
            self.sendSticker = sendSticker
            self.chatPeerId = chatPeerId
        }
    }
    
    public enum StaticEmojiSegment: Int32, CaseIterable {
        case people = 0
        case animalsAndNature = 1
        case foodAndDrink = 2
        case activityAndSport = 3
        case travelAndPlaces = 4
        case objects = 5
        case symbols = 6
        case flags = 7
    }
    
    public final class Item: Equatable {
        public let file: TelegramMediaFile?
        public let staticEmoji: String?
        public let subgroupId: Int32?
        
        public init(
            file: TelegramMediaFile?,
            staticEmoji: String?,
            subgroupId: Int32?
        ) {
            self.file = file
            self.staticEmoji = staticEmoji
            self.subgroupId = subgroupId
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.file?.fileId != rhs.file?.fileId {
                return false
            }
            if lhs.staticEmoji != rhs.staticEmoji {
                return false
            }
            if lhs.subgroupId != rhs.subgroupId {
                return false
            }
            
            return true
        }
    }
    
    public final class ItemGroup: Equatable {
        public let supergroupId: AnyHashable
        public let groupId: AnyHashable
        public let title: String?
        public let isFeatured: Bool
        public let isPremiumLocked: Bool
        public let hasClear: Bool
        public let displayPremiumBadges: Bool
        public let items: [Item]
        
        public init(
            supergroupId: AnyHashable,
            groupId: AnyHashable,
            title: String?,
            isFeatured: Bool,
            isPremiumLocked: Bool,
            hasClear: Bool,
            displayPremiumBadges: Bool,
            items: [Item]
        ) {
            self.supergroupId = supergroupId
            self.groupId = groupId
            self.title = title
            self.isFeatured = isFeatured
            self.isPremiumLocked = isPremiumLocked
            self.hasClear = hasClear
            self.displayPremiumBadges = displayPremiumBadges
            self.items = items
        }
        
        public static func ==(lhs: ItemGroup, rhs: ItemGroup) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.supergroupId != rhs.supergroupId {
                return false
            }
            if lhs.groupId != rhs.groupId {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.isFeatured != rhs.isFeatured {
                return false
            }
            if lhs.isPremiumLocked != rhs.isPremiumLocked {
                return false
            }
            if lhs.hasClear != rhs.hasClear {
                return false
            }
            if lhs.displayPremiumBadges != rhs.displayPremiumBadges {
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
            let supergroupId: AnyHashable
            let groupId: AnyHashable
            let hasTitle: Bool
            let isPremiumLocked: Bool
            let isFeatured: Bool
            let itemCount: Int
        }
        
        private struct ItemGroupLayout: Equatable {
            let frame: CGRect
            let supergroupId: AnyHashable
            let groupId: AnyHashable
            let itemTopOffset: CGFloat
            let itemCount: Int
        }
        
        private struct ItemLayout: Equatable {
            var width: CGFloat
            var containerInsets: UIEdgeInsets
            var itemGroupLayouts: [ItemGroupLayout]
            var nativeItemSize: CGFloat
            let visibleItemSize: CGFloat
            var horizontalSpacing: CGFloat
            var verticalSpacing: CGFloat
            var verticalGroupSpacing: CGFloat
            var itemsPerRow: Int
            var contentSize: CGSize
            
            var premiumButtonInset: CGFloat
            var premiumButtonHeight: CGFloat
            
            init(width: CGFloat, containerInsets: UIEdgeInsets, itemGroups: [ItemGroupDescription], itemLayoutType: ItemLayoutType) {
                self.width = width
                self.containerInsets = containerInsets
                
                self.premiumButtonInset = 6.0
                self.premiumButtonHeight = 50.0
                
                let minItemsPerRow: Int
                let minSpacing: CGFloat
                switch itemLayoutType {
                case .compact:
                    minItemsPerRow = 8
                    self.nativeItemSize = 36.0
                    self.verticalSpacing = 9.0
                    minSpacing = 9.0
                case .detailed:
                    minItemsPerRow = 5
                    self.nativeItemSize = 76.0
                    self.verticalSpacing = 2.0
                    minSpacing = 2.0
                }
                
                self.verticalGroupSpacing = 18.0
                
                let itemHorizontalSpace = width - self.containerInsets.left - self.containerInsets.right
                
                self.itemsPerRow = max(minItemsPerRow, Int((itemHorizontalSpace + minSpacing) / (self.nativeItemSize + minSpacing)))
                
                self.visibleItemSize = floor((itemHorizontalSpace - CGFloat(self.itemsPerRow - 1) * minSpacing) / CGFloat(self.itemsPerRow))
                
                self.horizontalSpacing = floor((itemHorizontalSpace - self.visibleItemSize * CGFloat(self.itemsPerRow)) / CGFloat(self.itemsPerRow - 1))
                
                var verticalGroupOrigin: CGFloat = self.containerInsets.top
                self.itemGroupLayouts = []
                for itemGroup in itemGroups {
                    var itemTopOffset: CGFloat = 0.0
                    if itemGroup.hasTitle {
                        itemTopOffset += 24.0
                    }
                    
                    let numRowsInGroup = (itemGroup.itemCount + (self.itemsPerRow - 1)) / self.itemsPerRow
                    var groupContentSize = CGSize(width: width, height: itemTopOffset + CGFloat(numRowsInGroup) * self.visibleItemSize + CGFloat(max(0, numRowsInGroup - 1)) * self.verticalSpacing)
                    if itemGroup.isPremiumLocked || itemGroup.isFeatured {
                        groupContentSize.height += self.premiumButtonInset + self.premiumButtonHeight
                    }
                    self.itemGroupLayouts.append(ItemGroupLayout(
                        frame: CGRect(origin: CGPoint(x: 0.0, y: verticalGroupOrigin), size: groupContentSize),
                        supergroupId: itemGroup.supergroupId,
                        groupId: itemGroup.groupId,
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
                        x: self.containerInsets.left + CGFloat(column) * (self.visibleItemSize + self.horizontalSpacing),
                        y: groupLayout.frame.minY + groupLayout.itemTopOffset + CGFloat(row) * (self.visibleItemSize + self.verticalSpacing)
                    ),
                    size: CGSize(
                        width: self.visibleItemSize,
                        height: self.visibleItemSize
                    )
                )
            }
            
            func visibleItems(for rect: CGRect) -> [(supergroupId: AnyHashable, groupId: AnyHashable, groupIndex: Int, groupItems: Range<Int>?)] {
                var result: [(supergroupId: AnyHashable, groupId: AnyHashable, groupIndex: Int, groupItems: Range<Int>?)] = []
                
                for groupIndex in 0 ..< self.itemGroupLayouts.count {
                    let group = self.itemGroupLayouts[groupIndex]
                    
                    if !rect.intersects(group.frame) {
                        continue
                    }
                    let offsetRect = rect.offsetBy(dx: -self.containerInsets.left, dy: -group.frame.minY - group.itemTopOffset)
                    var minVisibleRow = Int(floor((offsetRect.minY - self.verticalSpacing) / (self.visibleItemSize + self.verticalSpacing)))
                    minVisibleRow = max(0, minVisibleRow)
                    let maxVisibleRow = Int(ceil((offsetRect.maxY - self.verticalSpacing) / (self.visibleItemSize + self.verticalSpacing)))

                    let minVisibleIndex = minVisibleRow * self.itemsPerRow
                    let maxVisibleIndex = min(group.itemCount - 1, (maxVisibleRow + 1) * self.itemsPerRow - 1)
                    
                    result.append((
                        supergroupId: group.supergroupId,
                        groupId: group.groupId,
                        groupIndex: groupIndex,
                        groupItems: maxVisibleIndex >= minVisibleIndex ? (minVisibleIndex ..< (maxVisibleIndex + 1)) : nil
                    ))
                }
                
                return result
            }
        }
        
        public final class ItemPlaceholderView: UIView {
            private let shimmerView: PortalSourceView?
            private var placeholderView: PortalView?
            private let placeholderMaskLayer: SimpleLayer
            
            public init(
                context: AccountContext,
                file: TelegramMediaFile,
                shimmerView: PortalSourceView?,
                color: UIColor?,
                size: CGSize
            ) {
                self.shimmerView = shimmerView
                self.placeholderView = PortalView()
                self.placeholderMaskLayer = SimpleLayer()
                
                super.init(frame: CGRect())
                
                if let placeholderView = self.placeholderView, let shimmerView = self.shimmerView {
                    placeholderView.view.clipsToBounds = true
                    placeholderView.view.layer.mask = self.placeholderMaskLayer
                    self.addSubview(placeholderView.view)
                    shimmerView.addPortal(view: placeholderView)
                }
                
                Queue.concurrentDefaultQueue().async { [weak self] in
                    if let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: size, scale: min(2.0, UIScreenScale), imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: color ?? .black) {
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if let _ = color {
                                strongSelf.layer.contents = image.cgImage
                            } else {
                                strongSelf.placeholderMaskLayer.contents = image.cgImage
                            }
                        }
                    }
                }
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            public func update(size: CGSize) {
                if let placeholderView = self.placeholderView {
                    placeholderView.view.frame = CGRect(origin: CGPoint(), size: size)
                }
                self.placeholderMaskLayer.frame = CGRect(origin: CGPoint(), size: size)
            }
        }
        
        public final class ItemLayer: MultiAnimationRenderTarget {
            public struct Key: Hashable {
                var groupId: AnyHashable
                var fileId: MediaId?
                var staticEmoji: String?
                
                public init(
                    groupId: AnyHashable,
                    fileId: MediaId?,
                    staticEmoji: String?
                ) {
                    self.groupId = groupId
                    self.fileId = fileId
                    self.staticEmoji = staticEmoji
                }
            }
            
            enum Badge {
                case premium
                case locked
                case featured
            }
            
            let item: Item
            
            private let file: TelegramMediaFile?
            private let staticEmoji: String?
            private let placeholderColor: UIColor
            private let size: CGSize
            private var disposable: Disposable?
            private var fetchDisposable: Disposable?
            private var premiumBadgeView: PremiumBadgeView?
            
            private var badge: Badge?
            private var validSize: CGSize?
            
            private var isInHierarchyValue: Bool = false
            public var isVisibleForAnimations: Bool = false {
                didSet {
                    if self.isVisibleForAnimations != oldValue {
                        self.updatePlayback()
                    }
                }
            }
            public private(set) var displayPlaceholder: Bool = false
            public let onUpdateDisplayPlaceholder: (Bool, Double) -> Void
        
            public init(
                item: Item,
                context: AccountContext,
                attemptSynchronousLoad: Bool,
                file: TelegramMediaFile?,
                staticEmoji: String?,
                cache: AnimationCache,
                renderer: MultiAnimationRenderer,
                placeholderColor: UIColor,
                blurredBadgeColor: UIColor,
                pointSize: CGSize,
                onUpdateDisplayPlaceholder: @escaping (Bool, Double) -> Void
            ) {
                self.item = item
                self.file = file
                self.staticEmoji = staticEmoji
                self.placeholderColor = placeholderColor
                self.onUpdateDisplayPlaceholder = onUpdateDisplayPlaceholder
                
                let scale = min(2.0, UIScreenScale)
                let pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
                self.size = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
                
                super.init()
                
                if let file = file {
                    if file.isAnimatedSticker || file.isVideoEmoji {
                        let loadAnimation: () -> Void = { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.disposable = renderer.add(target: strongSelf, cache: cache, itemId: file.resource.id.stringRepresentation, size: pixelSize, fetch: { size, writer in
                                let source = AnimatedStickerResourceSource(account: context.account, resource: file.resource, fitzModifier: nil, isVideo: false)
                                
                                let dataDisposable = source.directDataPath(attemptSynchronously: false).start(next: { result in
                                    guard let result = result else {
                                        return
                                    }
                                    
                                    if file.isVideoEmoji {
                                        cacheVideoAnimation(path: result, width: Int(size.width), height: Int(size.height), writer: writer)
                                    } else if file.isAnimatedSticker {
                                        guard let data = try? Data(contentsOf: URL(fileURLWithPath: result)) else {
                                            writer.finish()
                                            return
                                        }
                                        cacheLottieAnimation(data: data, width: Int(size.width), height: Int(size.height), writer: writer)
                                    } else {
                                        cacheStillSticker(path: result, width: Int(size.width), height: Int(size.height), writer: writer)
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
                            if !renderer.loadFirstFrameSynchronously(target: self, cache: cache, itemId: file.resource.id.stringRepresentation, size: pixelSize) {
                                self.updateDisplayPlaceholder(displayPlaceholder: true)
                            }
                            
                            loadAnimation()
                        } else {
                            let _ = renderer.loadFirstFrame(target: self, cache: cache, itemId: file.resource.id.stringRepresentation, size: pixelSize, completion: { [weak self] success in
                                loadAnimation()
                                
                                if !success {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    strongSelf.updateDisplayPlaceholder(displayPlaceholder: true)
                                }
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
                } else if let staticEmoji = staticEmoji {
                    let image = generateImage(self.size, opaque: false, scale: min(UIScreenScale, 3.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        
                        let preScaleFactor: CGFloat = 2.0
                        let scaledSize = CGSize(width: floor(size.width * preScaleFactor), height: floor(size.height * preScaleFactor))
                        let scaleFactor = scaledSize.width / size.width
                        
                        context.scaleBy(x: 1.0 / scaleFactor, y: 1.0 / scaleFactor)
                        
                        let string = NSAttributedString(string: staticEmoji, font: Font.regular(floor(30.0 * scaleFactor)), textColor: .black)
                        let boundingRect = string.boundingRect(with: scaledSize, options: .usesLineFragmentOrigin, context: nil)
                        UIGraphicsPushContext(context)
                        string.draw(at: CGPoint(x: (scaledSize.width - boundingRect.width) / 2.0 + boundingRect.minX, y: (scaledSize.height - boundingRect.height) / 2.0 + boundingRect.minY))
                        UIGraphicsPopContext()
                    })
                    self.contents = image?.cgImage
                }
            }
            
            override public init(layer: Any) {
                guard let layer = layer as? ItemLayer else {
                    preconditionFailure()
                }
                
                self.item = layer.item
                
                self.file = layer.file
                self.staticEmoji = layer.staticEmoji
                self.placeholderColor = layer.placeholderColor
                self.size = layer.size
                
                self.onUpdateDisplayPlaceholder = { _, _ in }
                
                super.init(layer: layer)
            }
            
            required public init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            deinit {
                self.disposable?.dispose()
                self.fetchDisposable?.dispose()
            }
            
            public override func action(forKey event: String) -> CAAction? {
                if event == kCAOnOrderIn {
                    self.isInHierarchyValue = true
                } else if event == kCAOnOrderOut {
                    self.isInHierarchyValue = false
                }
                self.updatePlayback()
                return nullAction
            }
            
            func update(transition: Transition, size: CGSize, badge: Badge?, blurredBadgeColor: UIColor, blurredBadgeBackgroundColor: UIColor) {
                if self.badge != badge || self.validSize != size {
                    self.badge = badge
                    self.validSize = size
                    
                    if let badge = badge {
                        var badgeTransition = transition
                        let premiumBadgeView: PremiumBadgeView
                        if let current = self.premiumBadgeView {
                            premiumBadgeView = current
                        } else {
                            badgeTransition = .immediate
                            premiumBadgeView = PremiumBadgeView()
                            self.premiumBadgeView = premiumBadgeView
                            self.addSublayer(premiumBadgeView.layer)
                        }
                        
                        let badgeDiameter = min(16.0, floor(size.height * 0.5))
                        let badgeSize = CGSize(width: badgeDiameter, height: badgeDiameter)
                        badgeTransition.setFrame(view: premiumBadgeView, frame: CGRect(origin: CGPoint(x: size.width - badgeSize.width, y: size.height - badgeSize.height), size: badgeSize))
                        premiumBadgeView.update(transition: badgeTransition, badge: badge, backgroundColor: blurredBadgeColor, size: badgeSize)
                        
                        self.blurredRepresentationBackgroundColor = blurredBadgeBackgroundColor
                        self.blurredRepresentationTarget = premiumBadgeView.contentLayer
                    } else {
                        if let premiumBadgeView = self.premiumBadgeView {
                            self.premiumBadgeView = nil
                            premiumBadgeView.removeFromSuperview()
                            
                            self.blurredRepresentationBackgroundColor = nil
                            self.blurredRepresentationTarget = nil
                        }
                    }
                }
            }
            
            private func updatePlayback() {
                let shouldBePlaying = self.isInHierarchyValue && self.isVisibleForAnimations
                
                self.shouldBeAnimating = shouldBePlaying
            }
            
            public override func updateDisplayPlaceholder(displayPlaceholder: Bool) {
                if self.displayPlaceholder == displayPlaceholder {
                    return
                }
                
                self.displayPlaceholder = displayPlaceholder
                self.onUpdateDisplayPlaceholder(displayPlaceholder, 0.0)
            }
            
            public override func transitionToContents(_ contents: AnyObject) {
                self.contents = contents
                
                if self.displayPlaceholder {
                    self.displayPlaceholder = false
                    self.onUpdateDisplayPlaceholder(false, 0.2)
                    self.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                }
            }
        }
        
        private final class GroupBorderLayer: CAShapeLayer {
            override func action(forKey event: String) -> CAAction? {
                return nullAction
            }
            
            override init() {
                super.init()
            }
            
            override init(layer: Any) {
                super.init(layer: layer)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        
        private final class ContentScrollView: UIScrollView, PagerExpandableScrollView {
        }
        
        private let shimmerHostView: PortalSourceView
        private let standaloneShimmerEffect: StandaloneShimmerEffect
        
        private let scrollView: ContentScrollView
        private let boundsChangeTrackerLayer = SimpleLayer()
        private var effectiveVisibleSize: CGSize = CGSize()
        
        private let placeholdersContainerView: UIView
        private var visibleItemPlaceholderViews: [ItemLayer.Key: ItemPlaceholderView] = [:]
        private var visibleItemLayers: [ItemLayer.Key: ItemLayer] = [:]
        private var visibleGroupHeaders: [AnyHashable: GroupHeaderLayer] = [:]
        private var visibleGroupBorders: [AnyHashable: GroupBorderLayer] = [:]
        private var visibleGroupPremiumButtons: [AnyHashable: ComponentView<Empty>] = [:]
        private var ignoreScrolling: Bool = false
        private var keepTopPanelVisibleUntilScrollingInput: Bool = false
        
        private var component: EmojiPagerContentComponent?
        private weak var state: EmptyComponentState?
        private var pagerEnvironment: PagerComponentChildEnvironment?
        private var theme: PresentationTheme?
        private var activeItemUpdated: ActionSlot<(AnyHashable, AnyHashable?, Transition)>?
        private var itemLayout: ItemLayout?
        
        private var peekRecognizer: PeekControllerGestureRecognizer?
        private var currentContextGestureItemKey: ItemLayer.Key?
        private weak var peekController: PeekController?
        
        override init(frame: CGRect) {
            self.shimmerHostView = PortalSourceView()
            self.standaloneShimmerEffect = StandaloneShimmerEffect()
            
            self.scrollView = ContentScrollView()
            self.scrollView.layer.anchorPoint = CGPoint()
            
            self.placeholdersContainerView = UIView()
            
            super.init(frame: frame)
            
            self.shimmerHostView.alpha = 0.0
            self.addSubview(self.shimmerHostView)
            
            self.boundsChangeTrackerLayer.opacity = 0.0
            self.layer.addSublayer(self.boundsChangeTrackerLayer)
            self.boundsChangeTrackerLayer.didEnterHierarchy = { [weak self] in
                self?.standaloneShimmerEffect.updateLayer()
            }
            
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
            self.scrollView.clipsToBounds = false
            self.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.placeholdersContainerView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
            let peekRecognizer = PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
                guard let strongSelf = self, let component = strongSelf.component else {
                    return nil
                }
                guard let item = strongSelf.item(atPoint: point), let itemLayer = strongSelf.visibleItemLayers[item.1], let file = item.0.file else {
                    return nil
                }
                
                let context = component.context
                let accountPeerId = context.account.peerId
                return combineLatest(
                    context.engine.stickers.isStickerSaved(id: file.fileId),
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
                                        sendSticker(.standalone(media: file), true, false, nil, false, animationNode.view, animationNode.bounds, nil)
                                    } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                        sendSticker(.standalone(media: file), true, false, nil, false, imageNode.view, imageNode.bounds, nil)
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
                                    let _ = sendSticker(.standalone(media: file), false, true, nil, false, animationNode.view, animationNode.bounds, nil)
                                } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                    let _ = sendSticker(.standalone(media: file), false, true, nil, false, imageNode.view, imageNode.bounds, nil)
                                }
                            }
                            f(.default)
                        })))
                    }
                    
                    menuItems.append(
                        .action(ContextMenuActionItem(text: isStarred ? presentationData.strings.Stickers_RemoveFromFavorites : presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                            f(.default)
                            
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let _ = (context.engine.stickers.toggleStickerSaved(file: file, saved: !isStarred)
                            |> deliverOnMainQueue).start(next: { result in
                                switch result {
                                case .generic:
                                    component.inputInteraction.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, title: nil, text: !isStarred ? presentationData.strings.Conversation_StickerAddedToFavorites : presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }))
                                case let .limitExceeded(limit, premiumLimit):
                                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                    let text: String
                                    if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                        text = presentationData.strings.Premium_MaxFavedStickersFinalText
                                    } else {
                                        text = presentationData.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
                                    }
                                    component.inputInteraction.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, title: presentationData.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil, customAction: nil), elevatedLayout: false, action: { action in
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
                            
                            loop: for attribute in file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, _, packReference):
                                if let packReference = packReference {
                                    let controller = context.sharedContext.makeStickerPackScreen(context: context, updatedPresentationData: nil, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: component.inputInteraction.navigationController(), sendSticker: { file, sourceView, sourceRect in
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
                    
                    return (strongSelf, strongSelf.scrollView.convert(itemLayer.frame, to: strongSelf), StickerPreviewPeekContent(account: context.account, theme: presentationData.theme, strings: presentationData.strings, item: .pack(file), isLocked: file.isPremiumSticker && !hasPremium, menu: menuItems, openPremiumIntro: {
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
            self.peekRecognizer = peekRecognizer
            self.addGestureRecognizer(peekRecognizer)
            self.peekRecognizer?.isEnabled = false
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
        
        public func scrollToItemGroup(id supergroupId: AnyHashable, subgroupId: Int32?) {
            guard let component = self.component, let pagerEnvironment = self.pagerEnvironment, let itemLayout = self.itemLayout else {
                return
            }
            for groupIndex in 0 ..< itemLayout.itemGroupLayouts.count {
                let group = itemLayout.itemGroupLayouts[groupIndex]
                
                var subgroupItemIndex: Int?
                if group.supergroupId == supergroupId {
                    if let subgroupId = subgroupId {
                        inner: for itemGroup in component.itemGroups {
                            if itemGroup.supergroupId == supergroupId {
                                for i in 0 ..< itemGroup.items.count {
                                    if itemGroup.items[i].subgroupId == subgroupId {
                                        subgroupItemIndex = i
                                        break
                                    }
                                }
                                break inner
                            }
                        }
                    }
                    let wasIgnoringScrollingEvents = self.ignoreScrolling
                    self.ignoreScrolling = true
                    self.scrollView.setContentOffset(self.scrollView.contentOffset, animated: false)
                    
                    self.keepTopPanelVisibleUntilScrollingInput = true
                    
                    let anchorFrame: CGRect
                    if let subgroupItemIndex = subgroupItemIndex {
                        anchorFrame = itemLayout.frame(groupIndex: groupIndex, itemIndex: subgroupItemIndex)
                    } else {
                        anchorFrame = group.frame
                    }
                    
                    var scrollPosition = anchorFrame.minY + floor(-itemLayout.verticalGroupSpacing / 2.0) - pagerEnvironment.containerInsets.top
                    if scrollPosition > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                        scrollPosition = self.scrollView.contentSize.height - self.scrollView.bounds.height
                    }
                    if scrollPosition < 0.0 {
                        scrollPosition = 0.0
                    }
                    
                    let offsetDirectionSign: Double = scrollPosition < self.scrollView.bounds.minY ? -1.0 : 1.0
                    
                    var previousVisibleLayers: [ItemLayer.Key: (CALayer, CGRect)] = [:]
                    for (id, layer) in self.visibleItemLayers {
                        previousVisibleLayers[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisiblePlaceholderViews: [ItemLayer.Key: (UIView, CGRect)] = [:]
                    for (id, view) in self.visibleItemPlaceholderViews {
                        previousVisiblePlaceholderViews[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleGroupHeaders: [AnyHashable: (CALayer, CGRect)] = [:]
                    for (id, layer) in self.visibleGroupHeaders {
                        if !self.scrollView.bounds.intersects(layer.frame) {
                            continue
                        }
                        previousVisibleGroupHeaders[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleGroupBorders: [AnyHashable: (CALayer, CGRect)] = [:]
                    for (id, layer) in self.visibleGroupBorders {
                        previousVisibleGroupBorders[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleGroupPremiumButtons: [AnyHashable: (UIView, CGRect)] = [:]
                    for (id, view) in self.visibleGroupPremiumButtons {
                        if let view = view.view {
                            previousVisibleGroupPremiumButtons[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                        }
                    }
                    
                    self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: scrollPosition), size: self.scrollView.bounds.size)
                    self.ignoreScrolling = wasIgnoringScrollingEvents
                    
                    self.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: true)
                    
                    var commonItemOffset: CGFloat?
                    var previousVisibleBoundingRect: CGRect?
                    for (id, layerAndFrame) in previousVisibleLayers {
                        if let layer = self.visibleItemLayers[id] {
                            if commonItemOffset == nil {
                                let visibleFrame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = layerAndFrame.1
                            }
                        }
                    }
                    
                    for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                        if let view = self.visibleItemPlaceholderViews[id] {
                            if commonItemOffset == nil {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = viewAndFrame.1
                            }
                        }
                    }
                    
                    for (id, layerAndFrame) in previousVisibleGroupHeaders {
                        if let layer = self.visibleGroupHeaders[id] {
                            if commonItemOffset == nil, self.scrollView.bounds.intersects(layer.frame) {
                                let visibleFrame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = layerAndFrame.1
                            }
                        }
                    }
                    
                    /*for (id, layerAndFrame) in previousVisibleGroupBorders {
                        if let layer = self.visibleGroupBorders[id] {
                            if commonItemOffset == nil, self.scrollView.bounds.intersects(layer.frame) {
                                let visibleFrame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = layerAndFrame.1
                            }
                        }
                    }*/
                    
                    for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                        if let view = self.visibleGroupPremiumButtons[id]?.view, self.scrollView.bounds.intersects(view.frame) {
                            if commonItemOffset == nil {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = viewAndFrame.1
                            }
                        }
                    }
                    
                    let duration = 0.4
                    let timingFunction = kCAMediaTimingFunctionSpring
                    
                    if let commonItemOffset = commonItemOffset {
                        for (_, layer) in self.visibleItemLayers {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, layerAndFrame) in previousVisibleLayers {
                            if self.visibleItemLayers[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            self.scrollView.layer.addSublayer(layer)
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                layer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, view) in self.visibleItemPlaceholderViews {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                            if self.visibleItemPlaceholderViews[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.placeholdersContainerView.addSubview(view)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            })
                        }
                        
                        for (_, layer) in self.visibleGroupHeaders {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, layerAndFrame) in previousVisibleGroupHeaders {
                            if self.visibleGroupHeaders[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            self.scrollView.layer.addSublayer(layer)
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                layer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, layer) in self.visibleGroupBorders {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, layerAndFrame) in previousVisibleGroupBorders {
                            if self.visibleGroupBorders[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            self.scrollView.layer.addSublayer(layer)
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                layer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupPremiumButtons {
                            if let view = view.view {
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                        }
                        for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                            if self.visibleGroupPremiumButtons[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.scrollView.addSubview(view)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            })
                        }
                    } else if let previousVisibleBoundingRect = previousVisibleBoundingRect {
                        var updatedVisibleBoundingRect: CGRect?
                        
                        for (_, layer) in self.visibleItemLayers {
                            let frame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        for (_, view) in self.visibleItemPlaceholderViews {
                            let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        for (_, layer) in self.visibleGroupHeaders {
                            if !self.scrollView.bounds.intersects(layer.frame) {
                                continue
                            }
                            let frame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        for (_, view) in self.visibleGroupPremiumButtons {
                            if let view = view.view {
                                if !self.scrollView.bounds.intersects(view.frame) {
                                    continue
                                }
                                
                                let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                    updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                                } else {
                                    updatedVisibleBoundingRect = frame
                                }
                            }
                        }
                        
                        if let updatedVisibleBoundingRect = updatedVisibleBoundingRect {
                            var commonItemOffset = updatedVisibleBoundingRect.height * offsetDirectionSign
                            
                            if previousVisibleBoundingRect.intersects(updatedVisibleBoundingRect) {
                                if offsetDirectionSign < 0.0 {
                                    commonItemOffset = previousVisibleBoundingRect.minY - updatedVisibleBoundingRect.maxY
                                } else {
                                    commonItemOffset = previousVisibleBoundingRect.maxY - updatedVisibleBoundingRect.minY
                                }
                            }
                            
                            for (_, layer) in self.visibleItemLayers {
                                layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, layerAndFrame) in previousVisibleLayers {
                                if self.visibleItemLayers[id] != nil {
                                    continue
                                }
                                let layer = layerAndFrame.0
                                layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.layer.addSublayer(layer)
                                layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                    layer?.removeFromSuperlayer()
                                })
                            }
                            
                            for (_, view) in self.visibleItemPlaceholderViews {
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                                if self.visibleItemPlaceholderViews[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.placeholdersContainerView.addSubview(view)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                    view?.removeFromSuperview()
                                })
                            }
                            
                            for (_, layer) in self.visibleGroupHeaders {
                                if !self.scrollView.bounds.intersects(layer.frame) {
                                    continue
                                }
                                layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, layerAndFrame) in previousVisibleGroupHeaders {
                                if self.visibleGroupHeaders[id] != nil {
                                    continue
                                }
                                let layer = layerAndFrame.0
                                layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.layer.addSublayer(layer)
                                layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                    layer?.removeFromSuperlayer()
                                })
                            }
                            
                            for (_, layer) in self.visibleGroupBorders {
                                if !self.scrollView.bounds.intersects(layer.frame) {
                                    continue
                                }
                                layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, layerAndFrame) in previousVisibleGroupBorders {
                                if self.visibleGroupBorders[id] != nil {
                                    continue
                                }
                                let layer = layerAndFrame.0
                                layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.layer.addSublayer(layer)
                                layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                    layer?.removeFromSuperlayer()
                                })
                            }
                            
                            for (_, view) in self.visibleGroupPremiumButtons {
                                if let view = view.view {
                                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                                }
                            }
                            for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                                if self.visibleGroupPremiumButtons[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.addSubview(view)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                    view?.removeFromSuperview()
                                })
                            }
                        }
                    }
                }
            }
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                let locationInScrollView = recognizer.location(in: self.scrollView)
                outer: for (id, groupHeader) in self.visibleGroupHeaders {
                    if groupHeader.frame.insetBy(dx: -10.0, dy: -6.0).contains(locationInScrollView) {
                        let groupHeaderPoint = self.scrollView.layer.convert(locationInScrollView, to: groupHeader)
                        if let clearIconLayer = groupHeader.clearIconLayer, clearIconLayer.frame.insetBy(dx: -4.0, dy: -4.0).contains(groupHeaderPoint) {
                            component.inputInteraction.clearGroup(id)
                        }
                        
                        /*for group in component.itemGroups {
                            if group.groupId == id {
                                if group.isPremium && !self.expandedPremiumGroups.contains(id) {
                                    if self.expandedPremiumGroups.contains(id) {
                                        self.expandedPremiumGroups.remove(id)
                                    } else {
                                        self.expandedPremiumGroups.insert(id)
                                    }
                                    
                                    let previousItemLayout = self.itemLayout
                                    
                                    let transition = Transition(animation: .curve(duration: 0.25, curve: .easeInOut))
                                    self.state?.updated(transition: transition)
                                    
                                    if let previousItemLayout = previousItemLayout, let itemLayout = self.itemLayout {
                                        let boundsOffset = itemLayout.contentSize.height - previousItemLayout.contentSize.height
                                        self.scrollView.setContentOffset(CGPoint(x: 0.0, y: self.scrollView.contentOffset.y + boundsOffset), animated: false)
                                        transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: -boundsOffset), to: CGPoint(), additive: true)
                                    }
                                    
                                    return
                                } else {
                                    break outer
                                }
                            }
                        }*/
                    }
                }
                
                if let (item, itemKey) = self.item(atPoint: recognizer.location(in: self)), let itemLayer = self.visibleItemLayers[itemKey] {
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
            if self.keepTopPanelVisibleUntilScrollingInput {
                self.keepTopPanelVisibleUntilScrollingInput = false
                
                self.updateScrollingOffset(isReset: true, transition: .immediate)
            }
            if let presentation = scrollView.layer.presentation() {
                scrollView.bounds = presentation.bounds
                scrollView.layer.removeAllAnimations()
            }
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            
            self.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: false)
            
            self.updateScrollingOffset(isReset: false, transition: .immediate)
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
        
        private func updateScrollingOffset(isReset: Bool, transition: Transition) {
            guard let component = self.component else {
                return
            }

            let isInteracting = scrollView.isDragging || scrollView.isDecelerating
            if let previousScrollingOffsetValue = self.previousScrollingOffset, !self.keepTopPanelVisibleUntilScrollingInput {
                let currentBounds = scrollView.bounds
                let offsetToTopEdge = max(0.0, currentBounds.minY - 0.0)
                let offsetToBottomEdge = max(0.0, scrollView.contentSize.height - currentBounds.maxY)
                
                let relativeOffset = scrollView.contentOffset.y - previousScrollingOffsetValue.value
                if case .detailed = component.itemLayoutType {
                    self.pagerEnvironment?.onChildScrollingUpdate(PagerComponentChildEnvironment.ContentScrollingUpdate(
                        relativeOffset: relativeOffset,
                        absoluteOffsetToTopEdge: offsetToTopEdge,
                        absoluteOffsetToBottomEdge: offsetToBottomEdge,
                        isReset: isReset,
                        isInteracting: isInteracting,
                        transition: transition
                    ))
                }
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
            
            self.updateScrollingOffset(isReset: false, transition: transition)
        }
        
        private func updateVisibleItems(transition: Transition, attemptSynchronousLoads: Bool) {
            guard let component = self.component, let pagerEnvironment = self.pagerEnvironment, let theme = self.theme, let itemLayout = self.itemLayout else {
                return
            }
            
            var topVisibleGroupId: AnyHashable?
            var topVisibleSubgroupId: AnyHashable?
            
            var validIds = Set<ItemLayer.Key>()
            var validGroupHeaderIds = Set<AnyHashable>()
            var validGroupBorderIds = Set<AnyHashable>()
            var validGroupPremiumButtonIds = Set<AnyHashable>()
            
            let effectiveVisibleBounds = CGRect(origin: self.scrollView.bounds.origin, size: self.effectiveVisibleSize)
            let topVisibleDetectionBounds = effectiveVisibleBounds.offsetBy(dx: 0.0, dy: pagerEnvironment.containerInsets.top)
            
            for groupItems in itemLayout.visibleItems(for: effectiveVisibleBounds) {
                let itemGroup = component.itemGroups[groupItems.groupIndex]
                let itemGroupLayout = itemLayout.itemGroupLayouts[groupItems.groupIndex]
                
                var assignTopVisibleSubgroupId = false
                if topVisibleGroupId == nil && itemGroupLayout.frame.intersects(topVisibleDetectionBounds) {
                    topVisibleGroupId = groupItems.supergroupId
                    assignTopVisibleSubgroupId = true
                }
                
                var headerSize: CGSize?
                var headerSizeUpdated = false
                if let title = itemGroup.title {
                    validGroupHeaderIds.insert(itemGroup.groupId)
                    let groupHeaderLayer: GroupHeaderLayer
                    var groupHeaderTransition = transition
                    if let current = self.visibleGroupHeaders[itemGroup.groupId] {
                        groupHeaderLayer = current
                    } else {
                        groupHeaderTransition = .immediate
                        groupHeaderLayer = GroupHeaderLayer()
                        self.visibleGroupHeaders[itemGroup.groupId] = groupHeaderLayer
                        self.scrollView.layer.addSublayer(groupHeaderLayer)
                    }
                    let groupHeaderSize = groupHeaderLayer.update(theme: theme, title: title, isPremiumLocked: itemGroup.isPremiumLocked, hasClear: itemGroup.hasClear, constrainedWidth: itemLayout.contentSize.width - itemLayout.containerInsets.left - itemLayout.containerInsets.right)
                    
                    if groupHeaderLayer.bounds.size != groupHeaderSize {
                        headerSizeUpdated = true
                    }
                    
                    let groupHeaderFrame = CGRect(origin: CGPoint(x: floor((itemLayout.contentSize.width - groupHeaderSize.width) / 2.0), y: itemGroupLayout.frame.minY + 1.0), size: groupHeaderSize)
                    groupHeaderLayer.bounds = CGRect(origin: CGPoint(), size: groupHeaderFrame.size)
                    groupHeaderTransition.setPosition(layer: groupHeaderLayer, position: CGPoint(x: groupHeaderFrame.midX, y: groupHeaderFrame.midY))
                    headerSize = CGSize(width: groupHeaderSize.width, height: groupHeaderSize.height)
                }
                
                let groupBorderRadius: CGFloat = 16.0
                
                if itemGroup.isPremiumLocked {
                    validGroupBorderIds.insert(itemGroup.groupId)
                    let groupBorderLayer: GroupBorderLayer
                    var groupBorderTransition = transition
                    if let current = self.visibleGroupBorders[itemGroup.groupId] {
                        groupBorderLayer = current
                    } else {
                        groupBorderTransition = .immediate
                        groupBorderLayer = GroupBorderLayer()
                        self.visibleGroupBorders[itemGroup.groupId] = groupBorderLayer
                        self.scrollView.layer.insertSublayer(groupBorderLayer, at: 0)
                        
                        groupBorderLayer.strokeColor = theme.chat.inputMediaPanel.stickersSectionTextColor.cgColor
                        groupBorderLayer.lineWidth = 1.6
                        groupBorderLayer.lineCap = .round
                        groupBorderLayer.fillColor = nil
                    }
                    
                    let groupBorderHorizontalInset: CGFloat = itemLayout.containerInsets.left - 4.0
                    let groupBorderVerticalTopOffset: CGFloat = 8.0
                    let groupBorderVerticalInset: CGFloat = 6.0
                    
                    let groupBorderFrame = CGRect(origin: CGPoint(x: groupBorderHorizontalInset, y: itemGroupLayout.frame.minY + groupBorderVerticalTopOffset), size: CGSize(width: itemLayout.width - groupBorderHorizontalInset * 2.0, height: itemGroupLayout.frame.size.height - groupBorderVerticalTopOffset + groupBorderVerticalInset))
                    
                    if groupBorderLayer.bounds.size != groupBorderFrame.size || headerSizeUpdated {
                        let headerWidth: CGFloat
                        if let headerSize = headerSize {
                            headerWidth = headerSize.width + 14.0
                        } else {
                            headerWidth = 0.0
                        }
                        let path = CGMutablePath()
                        let radius = groupBorderRadius
                        path.move(to: CGPoint(x: floor((groupBorderFrame.width - headerWidth) / 2.0), y: 0.0))
                        path.addLine(to: CGPoint(x: radius, y: 0.0))
                        path.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: 0.0, y: radius), radius: radius)
                        path.addLine(to: CGPoint(x: 0.0, y: groupBorderFrame.height - radius))
                        path.addArc(tangent1End: CGPoint(x: 0.0, y: groupBorderFrame.height), tangent2End: CGPoint(x: radius, y: groupBorderFrame.height), radius: radius)
                        path.addLine(to: CGPoint(x: groupBorderFrame.width - radius, y: groupBorderFrame.height))
                        path.addArc(tangent1End: CGPoint(x: groupBorderFrame.width, y: groupBorderFrame.height), tangent2End: CGPoint(x: groupBorderFrame.width, y: groupBorderFrame.height - radius), radius: radius)
                        path.addLine(to: CGPoint(x: groupBorderFrame.width, y: radius))
                        path.addArc(tangent1End: CGPoint(x: groupBorderFrame.width, y: 0.0), tangent2End: CGPoint(x: groupBorderFrame.width - radius, y: 0.0), radius: radius)
                        path.addLine(to: CGPoint(x: floor((groupBorderFrame.width - headerWidth) / 2.0) + headerWidth, y: 0.0))
                        
                        let pathLength = (2.0 * groupBorderFrame.width + 2.0 * groupBorderFrame.height - 8.0 * radius + 2.0 * .pi * radius) - headerWidth
                        
                        var numberOfDashes = Int(floor(pathLength / 6.0))
                        if numberOfDashes % 2 == 0 {
                            numberOfDashes -= 1
                        }
                        let wholeLength = 6.0 * CGFloat(numberOfDashes)
                        let remainingLength = pathLength - wholeLength
                        let dashSpace = remainingLength / CGFloat(numberOfDashes)
                        
                        groupBorderTransition.setShapeLayerPath(layer: groupBorderLayer, path: path)
                        groupBorderTransition.setShapeLayerLineDashPattern(layer: groupBorderLayer, pattern: [(5.0 + dashSpace) as NSNumber, (7.0 + dashSpace) as NSNumber])
                    }
                    groupBorderTransition.setFrame(layer: groupBorderLayer, frame: groupBorderFrame)
                }
                
                if itemGroup.isPremiumLocked || itemGroup.isFeatured {
                    let groupPremiumButtonMeasuringFrame = CGRect(origin: CGPoint(x: itemLayout.containerInsets.left, y: itemGroupLayout.frame.maxY - 50.0 + 1.0), size: CGSize(width: 100.0, height: 50.0))
                    
                    if effectiveVisibleBounds.intersects(groupPremiumButtonMeasuringFrame) {
                        validGroupPremiumButtonIds.insert(itemGroup.groupId)
                        
                        let groupPremiumButton: ComponentView<Empty>
                        var groupPremiumButtonTransition = transition
                        if let current = self.visibleGroupPremiumButtons[itemGroup.groupId] {
                            groupPremiumButton = current
                        } else {
                            groupPremiumButtonTransition = .immediate
                            groupPremiumButton = ComponentView<Empty>()
                            self.visibleGroupPremiumButtons[itemGroup.groupId] = groupPremiumButton
                        }
                        
                        let groupId = itemGroup.groupId
                        let isPremiumLocked = itemGroup.isPremiumLocked
                        
                        //TODO:localize
                        let title: String
                        let backgroundColor: UIColor
                        let backgroundColors: [UIColor]
                        let foregroundColor: UIColor
                        let animationName: String?
                        let gloss: Bool
                        if itemGroup.isPremiumLocked {
                            title = "Unlock \(itemGroup.title ?? "Emoji")"
                            backgroundColors = [
                                UIColor(rgb: 0x0077ff),
                                UIColor(rgb: 0x6b93ff),
                                UIColor(rgb: 0x8878ff),
                                UIColor(rgb: 0xe46ace)
                            ]
                            backgroundColor = backgroundColors[0]
                            foregroundColor = .white
                            animationName = "premium_unlock"
                            gloss = true
                        } else {
                            title = "Add \(itemGroup.title ?? "Emoji")"
                            backgroundColors = []
                            backgroundColor = theme.list.itemCheckColors.fillColor
                            foregroundColor = theme.list.itemCheckColors.foregroundColor
                            animationName = nil
                            gloss = false
                        }
                        
                        let groupPremiumButtonSize = groupPremiumButton.update(
                            transition: groupPremiumButtonTransition,
                            component: AnyComponent(SolidRoundedButtonComponent(
                                title: title,
                                theme: SolidRoundedButtonComponent.Theme(
                                    backgroundColor: backgroundColor,
                                    backgroundColors: backgroundColors,
                                    foregroundColor: foregroundColor
                                ),
                                font: .bold,
                                fontSize: 17.0,
                                height: 50.0,
                                cornerRadius: groupBorderRadius,
                                gloss: gloss,
                                animationName: animationName,
                                iconPosition: .right,
                                iconSpacing: 4.0,
                                action: { [weak self] in
                                    guard let strongSelf = self, let component = strongSelf.component else {
                                        return
                                    }
                                    component.inputInteraction.addGroupAction(groupId, isPremiumLocked)
                                }
                            )),
                            environment: {},
                            containerSize: CGSize(width: itemLayout.width - itemLayout.containerInsets.left - itemLayout.containerInsets.right, height: itemLayout.premiumButtonHeight)
                        )
                        let groupPremiumButtonFrame = CGRect(origin: CGPoint(x: itemLayout.containerInsets.left, y: itemGroupLayout.frame.maxY - groupPremiumButtonSize.height + 1.0), size: groupPremiumButtonSize)
                        if let view = groupPremiumButton.view {
                            var animateIn = false
                            if view.superview == nil {
                                view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
                                animateIn = true
                                self.scrollView.addSubview(view)
                            }
                            groupPremiumButtonTransition.setFrame(view: view, frame: groupPremiumButtonFrame)
                            if animateIn, !transition.animation.isImmediate {
                                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                transition.animateScale(view: view, from: 0.01, to: 1.0)
                            }
                        }
                    }
                }
                
                if let groupItemRange = groupItems.groupItems {
                    for index in groupItemRange.lowerBound ..< groupItemRange.upperBound {
                        let item = itemGroup.items[index]
                        
                        if assignTopVisibleSubgroupId {
                            if let subgroupId = item.subgroupId {
                                topVisibleSubgroupId = AnyHashable(subgroupId)
                            }
                        }
                        
                        let itemId = ItemLayer.Key(groupId: itemGroup.groupId, fileId: item.file?.fileId, staticEmoji: item.staticEmoji)
                        validIds.insert(itemId)
                        
                        let itemDimensions: CGSize
                        if let file = item.file {
                            itemDimensions = file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
                        } else {
                            itemDimensions = CGSize(width: 512.0, height: 512.0)
                        }
                        let itemNativeFitSize = itemDimensions.fitted(CGSize(width: itemLayout.nativeItemSize, height: itemLayout.nativeItemSize))
                        let itemVisibleFitSize = itemDimensions.fitted(CGSize(width: itemLayout.visibleItemSize, height: itemLayout.visibleItemSize))
                        
                        var updateItemLayerPlaceholder = false
                        var itemTransition = transition
                        let itemLayer: ItemLayer
                        if let current = self.visibleItemLayers[itemId] {
                            itemLayer = current
                        } else {
                            updateItemLayerPlaceholder = true
                            itemTransition = .immediate
                            
                            itemLayer = ItemLayer(
                                item: item,
                                context: component.context,
                                attemptSynchronousLoad: attemptSynchronousLoads,
                                file: item.file,
                                staticEmoji: item.staticEmoji,
                                cache: component.animationCache,
                                renderer: component.animationRenderer,
                                placeholderColor: theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.1),
                                blurredBadgeColor: theme.chat.inputPanel.panelBackgroundColor.withMultipliedAlpha(0.5),
                                pointSize: itemNativeFitSize,
                                onUpdateDisplayPlaceholder: { [weak self] displayPlaceholder, duration in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    if displayPlaceholder, let file = item.file {
                                        if let itemLayer = strongSelf.visibleItemLayers[itemId] {
                                            let placeholderView: ItemPlaceholderView
                                            if let current = strongSelf.visibleItemPlaceholderViews[itemId] {
                                                placeholderView = current
                                            } else {
                                                placeholderView = ItemPlaceholderView(
                                                    context: component.context,
                                                    file: file,
                                                    shimmerView: strongSelf.shimmerHostView,
                                                    color: nil,
                                                    size: itemNativeFitSize
                                                )
                                                strongSelf.visibleItemPlaceholderViews[itemId] = placeholderView
                                                strongSelf.placeholdersContainerView.addSubview(placeholderView)
                                            }
                                            placeholderView.frame = itemLayer.frame
                                            placeholderView.update(size: placeholderView.bounds.size)
                                            
                                            strongSelf.updateShimmerIfNeeded()
                                        }
                                    } else {
                                        if let placeholderView = strongSelf.visibleItemPlaceholderViews[itemId] {
                                            strongSelf.visibleItemPlaceholderViews.removeValue(forKey: itemId)
                                            
                                            if duration > 0.0 {
                                                placeholderView.layer.opacity = 0.0
                                                placeholderView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, completion: { [weak self, weak placeholderView] _ in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    placeholderView?.removeFromSuperview()
                                                    strongSelf.updateShimmerIfNeeded()
                                                })
                                            } else {
                                                placeholderView.removeFromSuperview()
                                                strongSelf.updateShimmerIfNeeded()
                                            }
                                        }
                                    }
                                }
                            )
                            self.scrollView.layer.addSublayer(itemLayer)
                            self.visibleItemLayers[itemId] = itemLayer
                        }
                        
                        var itemFrame = itemLayout.frame(groupIndex: groupItems.groupIndex, itemIndex: index)
                        
                        itemFrame.origin.x += floor((itemFrame.width - itemVisibleFitSize.width) / 2.0)
                        itemFrame.origin.y += floor((itemFrame.height - itemVisibleFitSize.height) / 2.0)
                        itemFrame.size = itemVisibleFitSize
                        
                        let itemPosition = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                        let itemBounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                        itemTransition.setPosition(layer: itemLayer, position: itemPosition)
                        itemTransition.setBounds(layer: itemLayer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                        
                        var badge: ItemLayer.Badge?
                        if itemGroup.displayPremiumBadges, let file = item.file, file.isPremiumSticker {
                            badge = .premium
                        }
                        itemLayer.update(transition: transition, size: itemFrame.size, badge: badge, blurredBadgeColor: UIColor(white: 0.0, alpha: 0.1), blurredBadgeBackgroundColor: theme.list.plainBackgroundColor)
                        
                        if let placeholderView = self.visibleItemPlaceholderViews[itemId] {
                            if placeholderView.layer.position != itemPosition || placeholderView.layer.bounds != itemBounds {
                                itemTransition.setFrame(view: placeholderView, frame: itemFrame)
                                placeholderView.update(size: itemFrame.size)
                            }
                        } else if updateItemLayerPlaceholder {
                            if itemLayer.displayPlaceholder {
                                itemLayer.onUpdateDisplayPlaceholder(true, 0.0)
                            }
                        }
                        
                        itemLayer.isVisibleForAnimations = true
                    }
                }
            }

            var removedPlaceholerViews = false
            var removedIds: [ItemLayer.Key] = []
            for (id, itemLayer) in self.visibleItemLayers {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    itemLayer.removeFromSuperlayer()
                }
            }
            for id in removedIds {
                self.visibleItemLayers.removeValue(forKey: id)
                
                if let view = self.visibleItemPlaceholderViews.removeValue(forKey: id) {
                    view.removeFromSuperview()
                    removedPlaceholerViews = true
                }
            }
            
            var removedGroupHeaderIds: [AnyHashable] = []
            for (id, groupHeaderLayer) in self.visibleGroupHeaders {
                if !validGroupHeaderIds.contains(id) {
                    removedGroupHeaderIds.append(id)
                    groupHeaderLayer.removeFromSuperlayer()
                }
            }
            for id in removedGroupHeaderIds {
                self.visibleGroupHeaders.removeValue(forKey: id)
            }
            
            var removedGroupBorderIds: [AnyHashable] = []
            for (id, groupBorderLayer) in self.visibleGroupBorders {
                if !validGroupBorderIds.contains(id) {
                    removedGroupBorderIds.append(id)
                    groupBorderLayer.removeFromSuperlayer()
                }
            }
            for id in removedGroupBorderIds {
                self.visibleGroupBorders.removeValue(forKey: id)
            }
            
            var removedGroupPremiumButtonIds: [AnyHashable] = []
            for (id, groupPremiumButton) in self.visibleGroupPremiumButtons {
                if !validGroupPremiumButtonIds.contains(id) {
                    removedGroupPremiumButtonIds.append(id)
                    groupPremiumButton.view?.removeFromSuperview()
                }
            }
            for id in removedGroupPremiumButtonIds {
                self.visibleGroupPremiumButtons.removeValue(forKey: id)
            }
            
            if removedPlaceholerViews {
                self.updateShimmerIfNeeded()
            }
            
            if let topVisibleGroupId = topVisibleGroupId {
                self.activeItemUpdated?.invoke((topVisibleGroupId, topVisibleSubgroupId, .immediate))
            }
        }
        
        private func updateShimmerIfNeeded() {
            if self.placeholdersContainerView.subviews.isEmpty {
                self.standaloneShimmerEffect.layer = nil
            } else {
                self.standaloneShimmerEffect.layer = self.shimmerHostView.layer
            }
        }
        
        func update(component: EmojiPagerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            self.peekRecognizer?.isEnabled = component.itemLayoutType == .detailed
            
            let keyboardChildEnvironment = environment[EntityKeyboardChildEnvironment.self].value
            
            self.theme = keyboardChildEnvironment.theme
            self.activeItemUpdated = keyboardChildEnvironment.getContentActiveItemUpdated(component.id)
            
            let pagerEnvironment = environment[PagerComponentChildEnvironment.self].value
            self.pagerEnvironment = pagerEnvironment
            
            transition.setFrame(view: self.shimmerHostView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let shimmerBackgroundColor = keyboardChildEnvironment.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.08)
            let shimmerForegroundColor = keyboardChildEnvironment.theme.list.itemBlocksBackgroundColor.withMultipliedAlpha(0.15)
            self.standaloneShimmerEffect.update(background: shimmerBackgroundColor, foreground: shimmerForegroundColor)
            
            var anchorItem: (key: ItemLayer.Key, frame: CGRect)?
            if let previousComponent = previousComponent, previousComponent.itemGroups != component.itemGroups {
                let effectiveVisibleBounds = CGRect(origin: self.scrollView.bounds.origin, size: self.effectiveVisibleSize)
                let topVisibleDetectionBounds = effectiveVisibleBounds.offsetBy(dx: 0.0, dy: pagerEnvironment.containerInsets.top)
                for (key, itemLayer) in self.visibleItemLayers {
                    if !topVisibleDetectionBounds.intersects(itemLayer.frame) {
                        continue
                    }
                    if let anchorItemValue = anchorItem {
                        if itemLayer.frame.minY < anchorItemValue.frame.minY {
                            anchorItem = (key, itemLayer.frame)
                        } else if itemLayer.frame.minY == anchorItemValue.frame.minY && itemLayer.frame.minX < anchorItemValue.frame.minX {
                            anchorItem = (key, itemLayer.frame)
                        }
                    } else {
                        anchorItem = (key, itemLayer.frame)
                    }
                }
                if let anchorItemValue = anchorItem {
                    anchorItem = (anchorItemValue.key, self.scrollView.convert(anchorItemValue.frame, to: self))
                }
            }
            
            var itemGroups: [ItemGroupDescription] = []
            for itemGroup in component.itemGroups {
                itemGroups.append(ItemGroupDescription(
                    supergroupId: itemGroup.supergroupId,
                    groupId: itemGroup.groupId,
                    hasTitle: itemGroup.title != nil,
                    isPremiumLocked: itemGroup.isPremiumLocked,
                    isFeatured: itemGroup.isFeatured,
                    itemCount: itemGroup.items.count
                ))
            }
            
            var itemTransition = transition
            
            let itemLayout = ItemLayout(width: availableSize.width, containerInsets: UIEdgeInsets(top: pagerEnvironment.containerInsets.top + 9.0, left: pagerEnvironment.containerInsets.left + 12.0, bottom: 9.0 + pagerEnvironment.containerInsets.bottom, right: pagerEnvironment.containerInsets.right + 12.0), itemGroups: itemGroups, itemLayoutType: component.itemLayoutType)
            if let previousItemLayout = self.itemLayout {
                if previousItemLayout.width != itemLayout.width {
                    itemTransition = .immediate
                }
            } else {
                itemTransition = .immediate
            }
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            transition.setPosition(view: self.scrollView, position: CGPoint())
            let previousSize = self.scrollView.bounds.size
            self.scrollView.bounds = CGRect(origin: self.scrollView.bounds.origin, size: availableSize)
            
            if availableSize.height > previousSize.height || transition.animation.isImmediate {
                self.boundsChangeTrackerLayer.removeAllAnimations()
                self.boundsChangeTrackerLayer.bounds = self.scrollView.bounds
                self.effectiveVisibleSize = self.scrollView.bounds.size
            } else {
                self.effectiveVisibleSize = CGSize(width: availableSize.width, height: max(self.effectiveVisibleSize.height, availableSize.height))
                transition.setBounds(layer: self.boundsChangeTrackerLayer, bounds: self.scrollView.bounds, completion: { [weak self] completed in
                    guard let strongSelf = self else {
                        return
                    }
                    let effectiveVisibleSize = strongSelf.scrollView.bounds.size
                    if strongSelf.effectiveVisibleSize != effectiveVisibleSize {
                        strongSelf.effectiveVisibleSize = effectiveVisibleSize
                        strongSelf.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: false)
                    }
                })
            }
            
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            if self.scrollView.scrollIndicatorInsets != pagerEnvironment.containerInsets {
                self.scrollView.scrollIndicatorInsets = pagerEnvironment.containerInsets
            }
            self.previousScrollingOffset = ScrollingOffsetState(value: scrollView.contentOffset.y, isDraggingOrDecelerating: scrollView.isDragging || scrollView.isDecelerating)
            
            if let anchorItem = anchorItem {
                outer: for i in 0 ..< component.itemGroups.count {
                    if component.itemGroups[i].groupId != anchorItem.key.groupId {
                        continue
                    }
                    for j in 0 ..< component.itemGroups[i].items.count {
                        let itemKey: ItemLayer.Key
                        if let file = component.itemGroups[i].items[j].file {
                            itemKey = ItemLayer.Key(groupId: component.itemGroups[i].groupId, fileId: file.fileId, staticEmoji: nil)
                        } else if let staticEmoji = component.itemGroups[i].items[j].staticEmoji {
                            itemKey = ItemLayer.Key(groupId: component.itemGroups[i].groupId, fileId: nil, staticEmoji: staticEmoji)
                        } else {
                            continue
                        }
                        
                        if itemKey == anchorItem.key {
                            let itemFrame = itemLayout.frame(groupIndex: i, itemIndex: j)
                            
                            var contentOffsetY = itemFrame.minY - anchorItem.frame.minY
                            if contentOffsetY > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                                contentOffsetY = self.scrollView.contentSize.height - self.scrollView.bounds.height
                            }
                            if contentOffsetY < 0.0 {
                                contentOffsetY = 0.0
                            }
                            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffsetY), animated: false)
                            
                            break outer
                        }
                    }
                }
            }
            
            self.ignoreScrolling = false
            
            self.updateVisibleItems(transition: itemTransition, attemptSynchronousLoads: !(scrollView.isDragging || scrollView.isDecelerating))
            
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
