import Foundation
import UIKit
import SwiftSignalKit
import Display
import AnimationCache
import MultiAnimationRenderer
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import EmojiTextAttachmentView
import TextFormat
import TelegramUIPreferences

public final class EmojiSuggestionsComponent: Component {
    public typealias EnvironmentType = Empty
    
    public struct Theme: Equatable {
        let backgroundColor: UIColor
        let textColor: UIColor
        let placeholderColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            textColor: UIColor,
            placeholderColor: UIColor
        ) {
            self.backgroundColor = backgroundColor
            self.textColor = textColor
            self.placeholderColor = placeholderColor
        }
    }
    
    public static func suggestionData(context: AccountContext, isSavedMessages: Bool, query: String) -> Signal<[TelegramMediaFile], NoError> {
        let hasPremium: Signal<Bool, NoError>
        if isSavedMessages {
            hasPremium = .single(true)
        } else {
            hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                guard case let .user(user) = peer else {
                    return false
                }
                return user.isPremium
            }
            |> distinctUntilChanged
        }
        
        return combineLatest(
            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
            context.account.viewTracker.featuredEmojiPacks(),
            hasPremium,
            context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings])
        )
        |> take(1)
        |> map { view, featuredEmojiPacks, hasPremium, sharedData -> [TelegramMediaFile] in
            var stickerSettings = StickerSettings.defaultSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
               stickerSettings = value
            }
            
            if !stickerSettings.suggestAnimatedEmoji {
                return []
            }
            
            var result: [TelegramMediaFile] = []
            
            let normalizedQuery = query.basicEmoji.0
            
            var existingIds = Set<EngineMedia.Id>()
            for entry in view.entries {
                guard let item = entry.item as? StickerPackItem, !item.file.isPremiumEmoji || hasPremium else {
                    continue
                }
                let stringRepresentations = item.getStringRepresentationsOfIndexKeys()
                for stringRepresentation in stringRepresentations {
                    if stringRepresentation == query || (!normalizedQuery.isEmpty && stringRepresentation == normalizedQuery) {
                        if !existingIds.contains(item.file.fileId) {
                            existingIds.insert(item.file.fileId)
                            result.append(item.file._parse())
                        }
                        break
                    }
                }
            }
            
            for featuredPack in featuredEmojiPacks {
                for item in featuredPack.topItems {
                    if let alt = item.file.customEmojiAlt {
                        if alt == query || (!normalizedQuery.isEmpty && alt == normalizedQuery) {
                            if !item.file.isPremiumEmoji || hasPremium {
                                if !existingIds.contains(item.file.fileId) {
                                    existingIds.insert(item.file.fileId)
                                    result.append(item.file._parse())
                                }
                            }
                        }
                    }
                }
            }
            
            return result
        }
    }
    
    public static func searchData(context: AccountContext, isSavedMessages: Bool, query: String) -> Signal<[TelegramMediaFile], NoError> {
        let hasPremium: Signal<Bool, NoError>
        if isSavedMessages {
            hasPremium = .single(true)
        } else {
            hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                guard case let .user(user) = peer else {
                    return false
                }
                return user.isPremium
            }
            |> distinctUntilChanged
        }
    
        if query.isSingleEmoji {
            return combineLatest(
                context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
                hasPremium
            )
            |> map { view, hasPremium -> [TelegramMediaFile] in
                var result: [TelegramMediaFile] = []
                
                for entry in view.entries {
                    guard let item = entry.item as? StickerPackItem, !item.file.isPremiumEmoji || hasPremium else {
                        continue
                    }
                    let stringRepresentations = item.getStringRepresentationsOfIndexKeys()
                    for stringRepresentation in stringRepresentations {
                        if stringRepresentation == query {
                            result.append(item.file._parse())
                            break
                        }
                    }
                }
                return result
            }
        } else {
            let languageCode = "en-US"
            var signal = context.engine.stickers.searchEmojiKeywords(inputLanguageCode: languageCode, query: query, completeMatch: query.count < 2)
            if !languageCode.lowercased().hasPrefix("en") {
                signal = signal
                |> mapToSignal { keywords in
                    return .single(keywords)
                    |> then(
                        context.engine.stickers.searchEmojiKeywords(inputLanguageCode: "en-US", query: query, completeMatch: query.count < 3)
                        |> map { englishKeywords in
                            return keywords + englishKeywords
                        }
                    )
                }
            }
            
            return signal
            |> mapToSignal { keywords -> Signal<[TelegramMediaFile], NoError> in
                return combineLatest(
                    context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
                    hasPremium
                )
                |> map { view, hasPremium -> [TelegramMediaFile] in
                    var result: [TelegramMediaFile] = []
                    
                    var allEmoticons: [String: String] = [:]
                    for keyword in keywords {
                        for emoticon in keyword.emoticons {
                            allEmoticons[emoticon] = keyword.keyword
                        }
                    }
                    
                    for entry in view.entries {
                        guard let item = entry.item as? StickerPackItem, !item.file.isPremiumEmoji || hasPremium else {
                            continue
                        }
                        let stringRepresentations = item.getStringRepresentationsOfIndexKeys()
                        for stringRepresentation in stringRepresentations {
                            if let _ = allEmoticons[stringRepresentation] {
                                result.append(item.file._parse())
                                break
                            }
                        }
                    }
                    
                    return result
                }
            }
        }
    }
    
    public let context: AccountContext
    public let theme: Theme
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer
    public let files: [TelegramMediaFile]
    public let action: (TelegramMediaFile) -> Void
    
    public init(
        context: AccountContext,
        userLocation: MediaResourceUserLocation,
        theme: Theme,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        files: [TelegramMediaFile],
        action: @escaping (TelegramMediaFile) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.files = files
        self.action = action
    }
    
    public static func ==(lhs: EmojiSuggestionsComponent, rhs: EmojiSuggestionsComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.animationCache !== rhs.animationCache {
            return false
        }
        if lhs.animationRenderer !== rhs.animationRenderer {
            return false
        }
        if lhs.files != rhs.files {
            return false
        }
        return true
    }

    public final class View: UIView, UIScrollViewDelegate {
        private struct ItemLayout: Equatable {
            let spacing: CGFloat
            let itemSize: CGFloat
            let verticalInset: CGFloat
            let itemCount: Int
            let contentSize: CGSize
            let sideInset: CGFloat
            
            init(itemCount: Int) {
                #if DEBUG
                //var itemCount = itemCount
                //itemCount = 100
                #endif
                
                self.spacing = 9.0
                self.itemSize = 38.0
                self.verticalInset = 5.0
                self.sideInset = 5.0
                self.itemCount = itemCount
                
                self.contentSize = CGSize(width: self.sideInset * 2.0 + CGFloat(self.itemCount - 1) * self.spacing + CGFloat(self.itemCount) * self.itemSize, height: self.itemSize + self.verticalInset * 2.0)
            }
            
            func frame(at index: Int) -> CGRect {
                return CGRect(origin: CGPoint(x: self.sideInset + CGFloat(index) * (self.spacing + self.itemSize), y: self.verticalInset), size: CGSize(width: self.itemSize, height: self.itemSize))
            }
        }
        
        private let blurView: BlurredBackgroundView
        private let backgroundLayer: SimpleShapeLayer
        private let shadowLayer: SimpleLayer
        private let scrollView: UIScrollView
        
        private var component: EmojiSuggestionsComponent?
        private var itemLayout: ItemLayout?
        private var ignoreScrolling: Bool = false
        
        private var visibleLayers: [EngineMedia.Id: InlineStickerItemLayer] = [:]
        
        override init(frame: CGRect) {
            self.blurView = BlurredBackgroundView(color: .clear, enableBlur: true)
            /*self.blurView.layer.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.blurView.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.blurView.layer.shadowRadius = 15.0
            self.blurView.layer.shadowOpacity = 0.15*/
            
            self.shadowLayer = SimpleLayer()
            self.shadowLayer.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.shadowLayer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.shadowLayer.shadowRadius = 15.0
            self.shadowLayer.shadowOpacity = 0.15
            
            self.backgroundLayer = SimpleShapeLayer()
            
            self.blurView.layer.mask = self.backgroundLayer
            
            self.scrollView = UIScrollView()
            
            super.init(frame: frame)
            
            self.disablesInteractiveTransitionGestureRecognizer = true
            self.disablesInteractiveKeyboardGestureRecognizer = true
            
            self.scrollView.layer.anchorPoint = CGPoint()
            self.scrollView.delaysContentTouches = false
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.layer.addSublayer(self.shadowLayer)
            self.addSubview(self.blurView)
            //self.layer.addSublayer(self.backgroundLayer)
            self.addSubview(self.scrollView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func item(at point: CGPoint) -> (CALayer, TelegramMediaFile)? {
            let location = self.convert(point, to: self.scrollView)
            if self.scrollView.bounds.contains(location) {
                var closestFile: (file: TelegramMediaFile, layer: CALayer, distance: CGFloat)?
                for (_, itemLayer) in self.visibleLayers {
                    guard let file = itemLayer.file else {
                        continue
                    }
                    let distance = abs(location.x - itemLayer.position.x)
                    if let (_, _, currentDistance) = closestFile {
                        if distance < currentDistance {
                            closestFile = (file, itemLayer, distance)
                        }
                    } else {
                        closestFile = (file, itemLayer, distance)
                    }
                }
                if let (file, itemLayer, _) = closestFile {
                    return (itemLayer, file)
                }
            }
            
            return nil
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                let location = recognizer.location(in: self.scrollView)
                if self.scrollView.bounds.contains(location) {
                    var closestFile: (file: TelegramMediaFile, distance: CGFloat)?
                    for (_, itemLayer) in self.visibleLayers {
                        guard let file = itemLayer.file else {
                            continue
                        }
                        let distance = abs(location.x - itemLayer.position.x)
                        if let (_, currentDistance) = closestFile {
                            if distance < currentDistance {
                                closestFile = (file, distance)
                            }
                        } else {
                            closestFile = (file, distance)
                        }
                    }
                    if let (file, _) = closestFile {
                        self.component?.action(file)
                    }
                }
            }
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateVisibleItems(synchronousLoad: false)
            }
        }
        
        private func updateVisibleItems(synchronousLoad: Bool) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }

            let visibleBounds = self.scrollView.bounds
            
            var visibleIds = Set<EngineMedia.Id>()
            for i in 0 ..< component.files.count {
                let itemFrame = itemLayout.frame(at: i)
                if visibleBounds.intersects(itemFrame) {
                    let item = component.files[i]
                    visibleIds.insert(item.fileId)
                    
                    let itemLayer: InlineStickerItemLayer
                    if let current = self.visibleLayers[item.fileId] {
                        itemLayer = current
                        itemLayer.dynamicColor = component.theme.textColor
                    } else {
                        itemLayer = InlineStickerItemLayer(
                            context: component.context,
                            userLocation: .other,
                            attemptSynchronousLoad: synchronousLoad,
                            emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: item.fileId.id, file: item),
                            file: item,
                            cache: component.animationCache,
                            renderer: component.animationRenderer,
                            placeholderColor: component.theme.placeholderColor,
                            pointSize: itemFrame.size,
                            dynamicColor: component.theme.textColor
                        )
                        self.visibleLayers[item.fileId] = itemLayer
                        self.scrollView.layer.addSublayer(itemLayer)
                    }
                    
                    itemLayer.frame = itemFrame
                    
                    itemLayer.isVisibleForAnimations = true
                }
            }
            
            var removedIds: [EngineMedia.Id] = []
            for (id, itemLayer) in self.visibleLayers {
                if !visibleIds.contains(id) {
                    itemLayer.removeFromSuperlayer()
                    removedIds.append(id)
                }
            }
            for id in removedIds {
                self.visibleLayers.removeValue(forKey: id)
            }
        }
        
        public func adjustBackground(relativePositionX: CGFloat) {
            let size = self.bounds.size
            if size.width.isZero {
                return
            }
            
            let radius: CGFloat = 10.0
            let notchSize = CGSize(width: 19.0, height: 7.5)
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: radius, y: 0.0))
            path.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: 0.0, y: radius), radius: radius)
            path.addLine(to: CGPoint(x: 0.0, y: size.height - notchSize.height - radius))
            path.addArc(tangent1End: CGPoint(x: 0.0, y: size.height - notchSize.height), tangent2End: CGPoint(x: radius, y: size.height - notchSize.height), radius: radius)
            
            let notchBase = CGPoint(x: min(size.width - radius - notchSize.width, max(radius, floor(relativePositionX - notchSize.width / 2.0))), y: size.height - notchSize.height)
            path.addLine(to: notchBase)
            path.addCurve(to: CGPoint(x: notchBase.x + 7.49968, y: notchBase.y + 5.32576), control1: CGPoint(x: notchBase.x + 2.10085, y: notchBase.y + 0.0), control2: CGPoint(x: notchBase.x + 5.41005, y: notchBase.y + 3.11103))
            path.addCurve(to: CGPoint(x: notchBase.x + 8.95665, y: notchBase.y + 6.61485), control1: CGPoint(x: notchBase.x + 8.2352, y: notchBase.y + 6.10531), control2: CGPoint(x: notchBase.x + 8.60297, y: notchBase.y + 6.49509))
            path.addCurve(to: CGPoint(x: notchBase.x + 9.91544, y: notchBase.y + 6.61599), control1: CGPoint(x: notchBase.x + 9.29432, y: notchBase.y + 6.72919), control2: CGPoint(x: notchBase.x + 9.5775, y: notchBase.y + 6.72953))
            path.addCurve(to: CGPoint(x: notchBase.x + 11.3772, y: notchBase.y + 5.32853), control1: CGPoint(x: notchBase.x + 10.2694, y: notchBase.y + 6.49707), control2: CGPoint(x: notchBase.x + 10.6387, y: notchBase.y + 6.10756))
            path.addCurve(to: CGPoint(x: notchBase.x + 19.0, y: notchBase.y + 0.0), control1: CGPoint(x: notchBase.x + 13.477, y: notchBase.y + 3.11363), control2: CGPoint(x: notchBase.x + 16.817, y: notchBase.y + 0.0))
            
            path.addLine(to: CGPoint(x: size.width - radius, y: size.height - notchSize.height))
            path.addArc(tangent1End: CGPoint(x: size.width, y: size.height - notchSize.height), tangent2End: CGPoint(x: size.width, y: size.height - notchSize.height - radius), radius: radius)
            path.addLine(to: CGPoint(x: size.width, y: radius))
            path.addArc(tangent1End: CGPoint(x: size.width, y: 0.0), tangent2End: CGPoint(x: size.width - radius, y: 0.0), radius: radius)
            path.addLine(to: CGPoint(x: radius, y: 0.0))
            
            self.shadowLayer.shadowPath = path
            self.shadowLayer.frame = CGRect(origin: CGPoint(), size: size)
            self.blurView.frame = CGRect(origin: CGPoint(), size: size)
            self.blurView.update(size: size, transition: .immediate)
            self.backgroundLayer.frame = CGRect(origin: CGPoint(), size: size)
            self.backgroundLayer.path = path
            //self.blurView.shadowPath = path
        }
        
        func update(component: EmojiSuggestionsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let height: CGFloat = 54.0
            
            if self.component?.theme.backgroundColor != component.theme.backgroundColor {
                self.backgroundLayer.fillColor = component.theme.backgroundColor.cgColor
                self.blurView.updateColor(color: component.theme.backgroundColor, transition: .immediate)
            }
            var resetScrollingPosition = false
            if self.component?.files != component.files {
                resetScrollingPosition = true
            }
            
            self.component = component
            
            let itemLayout = ItemLayout(itemCount: component.files.count)
            self.itemLayout = itemLayout
            
            let size = CGSize(width: min(availableSize.width, itemLayout.contentSize.width), height: height)
            
            let scrollFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: itemLayout.contentSize.height))
            
            self.ignoreScrolling = true
            if self.scrollView.frame != scrollFrame {
                self.scrollView.frame = scrollFrame
            }
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            if resetScrollingPosition {
                self.scrollView.contentOffset = CGPoint()
            }
            self.ignoreScrolling = false
            
            self.updateVisibleItems(synchronousLoad: resetScrollingPosition)
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public extension EmojiSuggestionsComponent.Theme {
    init(theme: PresentationTheme, backgroundColor: UIColor? = nil) {
        self.backgroundColor = backgroundColor ?? theme.list.plainBackgroundColor.withMultipliedAlpha(0.88)
        self.textColor = theme.list.itemPrimaryTextColor
        self.placeholderColor = theme.list.mediaPlaceholderColor
    }
}
