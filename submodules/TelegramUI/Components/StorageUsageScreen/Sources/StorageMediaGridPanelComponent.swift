import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import TelegramStringFormatting
import CheckNode
import AvatarNode
import PhotoResources
import SemanticStatusNode

private let badgeFont = Font.regular(12.0)
private let videoIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/MiniThumbnailPlay"), color: .white)

private final class MediaGridLayer: SimpleLayer {
    enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool)
    }
    
    private(set) var message: Message?
    private var disposable: Disposable?
    
    private var size: CGSize?
    private var selectionState: SelectionState = .none
    private var theme: PresentationTheme?
    private var checkLayer: CheckLayer?
    private let badgeOverlay: SimpleLayer
    
    override init() {
        self.badgeOverlay = SimpleLayer()
        self.badgeOverlay.contentsScale = UIScreenScale
        self.badgeOverlay.contentsGravity = .topRight
        
        super.init()
        
        self.isOpaque = true
        self.masksToBounds = true
        self.contentsGravity = .resizeAspectFill
        
        self.addSublayer(self.badgeOverlay)
    }
    
    override init(layer: Any) {
        self.badgeOverlay = SimpleLayer()
        
        guard let other = layer as? MediaGridLayer else {
            preconditionFailure()
        }
        
        super.init(layer: other)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func prepareForReuse() {
        self.message = nil
        
        if let disposable = self.disposable {
            self.disposable = nil
            disposable.dispose()
        }
    }
    
    func setup(context: AccountContext, strings: PresentationStrings, message: Message, size: Int64) {
        self.message = message
        
        var isVideo = false
        var dimensions: CGSize?
        var signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        for media in message.media {
            if let file = media as? TelegramMediaFile, let representation = file.previewRepresentations.last {
                isVideo = file.isVideo
                signal = chatWebpageSnippetFile(
                    account: context.account,
                    userLocation: .peer(message.id.peerId),
                    mediaReference: FileMediaReference.standalone(media: file).abstract,
                    representation: representation,
                    automaticFetch: false
                )
                dimensions = representation.dimensions.cgSize
            } else if let image = media as? TelegramMediaImage, let representation = image.representations.last {
                signal = mediaGridMessagePhoto(
                    account: context.account,
                    userLocation: .peer(message.id.peerId),
                    photoReference: ImageMediaReference.standalone(media: image),
                    automaticFetch: false
                )
                dimensions = representation.dimensions.cgSize
            }
        }
        
        if let signal, let dimensions {
            self.disposable = (signal
            |> map { generator -> UIImage? in
                return generator(TransformImageArguments(corners: ImageCorners(radius: 0.0), imageSize: dimensions, boundingSize: CGSize(width: 100.0, height: 100.0), intrinsicInsets: UIEdgeInsets()))?.generateImage()
            }
            |> deliverOnMainQueue).start(next: { [weak self] image in
                guard let self, let image else {
                    return
                }
                self.contents = image.cgImage
            })
        }
        
        let text: String = dataSizeString(Int(size), formatting: DataSizeStringFormatting(strings: strings, decimalSeparator: "."))
        let attributedText = NSAttributedString(string: text, font: badgeFont, textColor: .white)
        let textBounds = attributedText.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
        let textSize = CGSize(width: ceil(textBounds.width), height: ceil(textBounds.height))
        let textLeftInset: CGFloat
        let textRightInset: CGFloat = 6.0
        if isVideo {
            textLeftInset = 18.0
        } else {
            textLeftInset = textRightInset
        }
        let badgeSize = CGSize(width: textLeftInset + textRightInset + textSize.width, height: 18.0)
        self.badgeOverlay.contents = generateImage(badgeSize, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor(white: 0.0, alpha: 0.5).cgColor)
            context.setBlendMode(.copy)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.height, height: size.height)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
            context.fill(CGRect(origin: CGPoint(x: size.height * 0.5, y: 0.0), size: CGSize(width: size.width - size.height, height: size.height)))
            context.setBlendMode(.normal)
            
            UIGraphicsPushContext(context)
            
            if isVideo, let videoIcon {
                videoIcon.draw(at: CGPoint(x: 2.0, y: floor((size.height - videoIcon.size.height) / 2.0)))
            }
            
            attributedText.draw(in: textBounds.offsetBy(dx: textLeftInset, dy: UIScreenPixel + floor((size.height - textSize.height) * 0.5)))
            
            UIGraphicsPopContext()
        })?.cgImage
    }
    
    func updateSelection(size: CGSize, selectionState: SelectionState, theme: PresentationTheme, transition: Transition) {
        if self.size == size && self.selectionState == selectionState && self.theme === theme {
            return
        }
        
        self.selectionState = selectionState
        self.size = size
        
        let themeUpdated = self.theme !== theme
        self.theme = theme
        
        switch selectionState {
        case .none:
            if let checkLayer = self.checkLayer {
                self.checkLayer = nil
                if !transition.animation.isImmediate {
                    checkLayer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
                    checkLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak checkLayer] _ in
                        checkLayer?.removeFromSuperlayer()
                    })
                } else {
                    checkLayer.removeFromSuperlayer()
                }
            }
        case let .editing(isSelected):
            let checkWidth: CGFloat
            if size.width <= 60.0 {
                checkWidth = 22.0
            } else {
                checkWidth = 28.0
            }
            let checkSize = CGSize(width: checkWidth, height: checkWidth)
            let checkFrame = CGRect(origin: CGPoint(x: self.bounds.size.width - checkSize.width - 2.0, y: 2.0), size: checkSize)
            
            if let checkLayer = self.checkLayer {
                if checkLayer.bounds.size != checkFrame.size {
                    checkLayer.setNeedsDisplay()
                }
                transition.setFrame(layer: checkLayer, frame: checkFrame)
                if themeUpdated {
                    checkLayer.theme = CheckNodeTheme(theme: theme, style: .overlay)
                }
                checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
            } else {
                let checkLayer = CheckLayer(theme: CheckNodeTheme(theme: theme, style: .overlay))
                self.checkLayer = checkLayer
                self.addSublayer(checkLayer)
                checkLayer.frame = checkFrame
                checkLayer.setSelected(isSelected, animated: false)
                checkLayer.setNeedsDisplay()
                
                if !transition.animation.isImmediate {
                    checkLayer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                    checkLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.badgeOverlay.frame = CGRect(origin: CGPoint(x: size.width - 3.0, y: size.height - 3.0), size: CGSize(width: 0.0, height: 0.0))
    }
}

private final class MediaGridLayerDataContext {
    
}

final class StorageMediaGridPanelComponent: Component {    
    typealias EnvironmentType = StorageUsagePanelEnvironment
    
    final class Item: Equatable {
        let message: Message
        let size: Int64
        
        init(
            message: Message,
            size: Int64
        ) {
            self.message = message
            self.size = size
        }
        
        static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.message.id != rhs.message.id {
                return false
            }
            if lhs.size != rhs.size {
                return false
            }
            return true
        }
    }
    
    final class Items: Equatable {
        let items: [Item]
        
        init(items: [Item]) {
            self.items = items
        }
        
        static func ==(lhs: Items, rhs: Items) -> Bool {
            if lhs === rhs {
                return true
            }
            return lhs.items == rhs.items
        }
    }
    
    let context: AccountContext
    let items: Items?
    let selectionState: StorageUsageScreenComponent.SelectionState?
    let action: (EngineMessage.Id) -> Void
    let contextAction: (EngineMessage.Id, UIView, CGRect, ContextGesture) -> Void

    init(
        context: AccountContext,
        items: Items?,
        selectionState: StorageUsageScreenComponent.SelectionState?,
        action: @escaping (EngineMessage.Id) -> Void,
        contextAction: @escaping (EngineMessage.Id, UIView, CGRect, ContextGesture) -> Void
    ) {
        self.context = context
        self.items = items
        self.selectionState = selectionState
        self.action = action
        self.contextAction = contextAction
    }
    
    static func ==(lhs: StorageMediaGridPanelComponent, rhs: StorageMediaGridPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var width: CGFloat
        var itemCount: Int
        var nativeItemSize: CGFloat
        let visibleItemSize: CGFloat
        
        var itemInsets: UIEdgeInsets
        var itemSpacing: CGFloat
        var itemsPerRow: Int
        var contentSize: CGSize
        
        init(
            width: CGFloat,
            containerInsets: UIEdgeInsets,
            itemCount: Int
        ) {
            self.width = width
            self.itemCount = itemCount
            
            let minItemsPerRow: Int = 3
            let itemSpacing: CGFloat = UIScreenPixel
            self.itemSpacing = itemSpacing
            let itemInsets: UIEdgeInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left, bottom: containerInsets.bottom, right: containerInsets.right)
            self.nativeItemSize = 120.0

            self.itemInsets = itemInsets
            let itemHorizontalSpace = width - self.itemInsets.left - self.itemInsets.right
            self.itemsPerRow = max(minItemsPerRow, Int((itemHorizontalSpace + itemSpacing) / (self.nativeItemSize + itemSpacing)))
            let proposedItemSize = floor((itemHorizontalSpace - itemSpacing * (CGFloat(self.itemsPerRow) - 1.0)) / CGFloat(self.itemsPerRow))
            self.visibleItemSize = proposedItemSize
            
            let numRows = (itemCount + (self.itemsPerRow - 1)) / self.itemsPerRow
            
            self.contentSize = CGSize(
                width: width,
                height: self.itemInsets.top + self.itemInsets.bottom + CGFloat(numRows) * self.visibleItemSize + CGFloat(max(0, numRows - 1)) * self.itemSpacing
            )
        }
        
        func frame(itemIndex: Int) -> CGRect {
            let row = itemIndex / self.itemsPerRow
            let column = itemIndex % self.itemsPerRow
            
            var result = CGRect(
                origin: CGPoint(
                    x: self.itemInsets.left + CGFloat(column) * (self.visibleItemSize + self.itemSpacing),
                    y: self.itemInsets.top + CGFloat(row) * (self.visibleItemSize + self.itemSpacing)
                ),
                size: CGSize(
                    width: self.visibleItemSize,
                    height: self.visibleItemSize
                )
            )
            if column == self.itemsPerRow - 1 {
                result.size.width = max(result.size.width, self.width - self.itemInsets.right - result.minX)
            }
            return result
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: -self.itemInsets.left, dy: -self.itemInsets.top)
            var minVisibleRow = Int(floor((offsetRect.minY - self.itemSpacing) / (self.visibleItemSize + self.itemSpacing)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxY - self.itemSpacing) / (self.visibleItemSize + self.itemSpacing)))
            
            let minVisibleIndex = minVisibleRow * self.itemsPerRow
            let maxVisibleIndex = min(self.itemCount - 1, (maxVisibleRow + 1) * self.itemsPerRow - 1)
            
            return maxVisibleIndex >= minVisibleIndex ? (minVisibleIndex ..< (maxVisibleIndex + 1)) : nil
        }
    }
    
    class View: ContextControllerSourceView, UIScrollViewDelegate {
        private let scrollView: UIScrollView
        
        private var visibleLayers: [EngineMessage.Id: MediaGridLayer] = [:]
        private var layersAvailableForReuse: [MediaGridLayer] = []
        
        private var ignoreScrolling: Bool = false
        
        private var component: StorageMediaGridPanelComponent?
        private var environment: StorageUsagePanelEnvironment?
        private var itemLayout: ItemLayout?
        
        private weak var currentGestureItemLayer: MediaGridLayer?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.addSubview(self.scrollView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
            self.shouldBegin = { [weak self] point in
                guard let self else {
                    return false
                }
                
                var itemLayer: MediaGridLayer?
                let scrollPoint = self.convert(point, to: self.scrollView)
                for (_, itemLayerValue) in self.visibleLayers {
                    if itemLayerValue.frame.contains(scrollPoint) {
                        itemLayer = itemLayerValue
                        break
                    }
                }
                
                guard let itemLayer else {
                    return false
                }

                self.currentGestureItemLayer = itemLayer

                return true
            }

            self.customActivationProgress = { [weak self] progress, update in
                guard let self, let itemLayer = self.currentGestureItemLayer else {
                    return
                }

                let targetContentRect = CGRect(origin: CGPoint(), size: itemLayer.bounds.size)

                let scaleSide = itemLayer.bounds.width
                let minScale: CGFloat = max(0.7, (scaleSide - 15.0) / scaleSide)
                let currentScale = 1.0 * (1.0 - progress) + minScale * progress

                let originalCenterOffsetX: CGFloat = itemLayer.bounds.width / 2.0 - targetContentRect.midX
                let scaledCenterOffsetX: CGFloat = originalCenterOffsetX * currentScale

                let originalCenterOffsetY: CGFloat = itemLayer.bounds.height / 2.0 - targetContentRect.midY
                let scaledCenterOffsetY: CGFloat = originalCenterOffsetY * currentScale

                let scaleMidX: CGFloat = scaledCenterOffsetX - originalCenterOffsetX
                let scaleMidY: CGFloat = scaledCenterOffsetY - originalCenterOffsetY

                switch update {
                case .update:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    itemLayer.transform = sublayerTransform
                case .begin:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    itemLayer.transform = sublayerTransform
                case .ended:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    let previousTransform = itemLayer.transform
                    itemLayer.transform = sublayerTransform

                    itemLayer.animate(from: NSValue(caTransform3D: previousTransform), to: NSValue(caTransform3D: sublayerTransform), keyPath: "transform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                }
            }
            
            self.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component, let itemLayer = self.currentGestureItemLayer else {
                    return
                }
                self.currentGestureItemLayer = nil
                guard let message = itemLayer.message else {
                    return
                }
                let rect = self.convert(itemLayer.frame, from: self.scrollView)

                component.contextAction(message.id, self, rect, gesture)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
            var foundItemLayer: MediaGridLayer?
            for (_, itemLayer) in self.visibleLayers {
                if let message = itemLayer.message, message.id == messageId {
                    foundItemLayer = itemLayer
                }
            }
            guard let itemLayer = foundItemLayer else {
                return nil
            }
            
            let itemFrame = self.convert(itemLayer.frame, from: self.scrollView)
            let proxyNode = ASDisplayNode()
            proxyNode.frame = itemFrame
            if let contents = itemLayer.contents {
                if let image = contents as? UIImage {
                    proxyNode.contents = image.cgImage
                } else {
                    proxyNode.contents = contents
                }
            }
            proxyNode.isHidden = true
            self.addSubnode(proxyNode)

            let escapeNotification = EscapeNotification {
                proxyNode.removeFromSupernode()
            }

            return (proxyNode, proxyNode.bounds, {
                let view = UIView()
                view.frame = proxyNode.frame
                view.layer.contents = proxyNode.layer.contents
                escapeNotification.keep()
                return (view, nil)
            })
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let component = self.component else {
                    return
                }
                let point = recognizer.location(in: self.scrollView)
                for (id, itemLayer) in self.visibleLayers {
                    if itemLayer.frame.contains(point) {
                        component.action(id)
                        break
                    }
                }
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let environment = self.environment, let items = component.items, let itemLayout = self.itemLayout else {
                return
            }
            
            let _ = environment
            
            var validIds = Set<EngineMessage.Id>()
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -100.0)
            if let visibleItems = itemLayout.visibleItems(for: visibleBounds) {
                for index in visibleItems.lowerBound ..< visibleItems.upperBound {
                    if index >= items.items.count {
                        continue
                    }
                    
                    let item = items.items[index]
                    let id = item.message.id
                    validIds.insert(id)
                }
                
                var removeIds: [EngineMessage.Id] = []
                for (id, itemLayer) in self.visibleLayers {
                    if !validIds.contains(id) {
                        removeIds.append(id)
                        itemLayer.isHidden = true
                        self.layersAvailableForReuse.append(itemLayer)
                        itemLayer.prepareForReuse()
                    }
                }
                for id in removeIds {
                    self.visibleLayers.removeValue(forKey: id)
                }
                
                for index in visibleItems.lowerBound ..< visibleItems.upperBound {
                    if index >= items.items.count {
                        continue
                    }
                    
                    let item = items.items[index]
                    let id = item.message.id
                    
                    var setupItemLayer = false
                    
                    let itemLayer: MediaGridLayer
                    if let current = self.visibleLayers[id] {
                        itemLayer = current
                    } else if !self.layersAvailableForReuse.isEmpty {
                        setupItemLayer = true
                        itemLayer = self.layersAvailableForReuse.removeLast()
                        itemLayer.isHidden = false
                        self.visibleLayers[id] = itemLayer
                    } else {
                        setupItemLayer = true
                        itemLayer = MediaGridLayer()
                        self.visibleLayers[id] = itemLayer
                        self.scrollView.layer.addSublayer(itemLayer)
                    }
                    
                    let itemFrame = itemLayout.frame(itemIndex: index)
                    itemLayer.frame = itemFrame
                    
                    if setupItemLayer {
                        itemLayer.setup(context: component.context, strings: environment.strings, message: item.message, size: item.size)
                    }
                    
                    let itemSelectionState: MediaGridLayer.SelectionState
                    if let selectionState = component.selectionState {
                        itemSelectionState = .editing(isSelected: selectionState.selectedMessages.contains(id))
                    } else {
                        itemSelectionState = .none
                    }
                    
                    itemLayer.updateSelection(size: itemFrame.size, selectionState: itemSelectionState, theme: environment.theme, transition: transition)
                }
            }
        }
        
        func update(component: StorageMediaGridPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StorageUsagePanelEnvironment>, transition: Transition) -> CGSize {
            self.component = component
            
            let environment = environment[StorageUsagePanelEnvironment.self].value
            self.environment = environment
            
            
            let itemLayout = ItemLayout(
                width: availableSize.width,
                containerInsets: environment.containerInsets,
                itemCount: component.items?.items.count ?? 0
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            let contentOffset = self.scrollView.bounds.minY
            transition.setPosition(view: self.scrollView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            var scrollBounds = self.scrollView.bounds
            scrollBounds.size = availableSize
            if !environment.isScrollable {
                scrollBounds.origin = CGPoint()
            }
            transition.setBounds(view: self.scrollView, bounds: scrollBounds)
            self.scrollView.isScrollEnabled = environment.isScrollable
            let contentSize = CGSize(width: availableSize.width, height: itemLayout.contentSize.height)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.scrollView.scrollIndicatorInsets = environment.containerInsets
            if !transition.animation.isImmediate && self.scrollView.bounds.minY != contentOffset {
                let deltaOffset = self.scrollView.bounds.minY - contentOffset
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: -deltaOffset), to: CGPoint(), additive: true)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StorageUsagePanelEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
