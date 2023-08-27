import AsyncDisplayKit
import AVFoundation
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import RadialStatusNode
import TelegramStringFormatting
import GridMessageSelectionNode
import UniversalMediaPlayer
import ListMessageItem
import ChatMessageInteractiveMediaBadge
import SparseItemGrid
import ShimmerEffect
import QuartzCore
import DirectMediaImageCache
import ComponentFlow
import TelegramNotices
import TelegramUIPreferences
import CheckNode
import AppBundle
import InvisibleInkDustNode
import MediaPickerUI
import StoryContainerScreen
import EmptyStateIndicatorComponent

private let mediaBadgeBackgroundColor = UIColor(white: 0.0, alpha: 0.6)
private let mediaBadgeTextColor = UIColor.white

private final class VisualMediaItemInteraction {
    let openItem: (EngineStoryItem) -> Void
    let openItemContextActions: (EngineStoryItem, ASDisplayNode, CGRect, ContextGesture?) -> Void
    let toggleSelection: (Int32, Bool) -> Void
    
    var hiddenMedia = Set<Int32>()
    var selectedIds: Set<Int32>?
    
    init(
        openItem: @escaping (EngineStoryItem) -> Void,
        openItemContextActions: @escaping (EngineStoryItem, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        toggleSelection: @escaping (Int32, Bool) -> Void
    ) {
        self.openItem = openItem
        self.openItemContextActions = openItemContextActions
        self.toggleSelection = toggleSelection
    }
}

private final class VisualMediaHoleAnchor: SparseItemGrid.HoleAnchor {
    let storyId: Int32
    override var id: AnyHashable {
        return AnyHashable(self.storyId)
    }

    let indexValue: Int
    override var index: Int {
        return self.indexValue
    }

    let localMonthTimestamp: Int32
    override var tag: Int32 {
        return self.localMonthTimestamp
    }

    init(index: Int, storyId: Int32, localMonthTimestamp: Int32) {
        self.indexValue = index
        self.storyId = storyId
        self.localMonthTimestamp = localMonthTimestamp
    }
}

private final class VisualMediaItem: SparseItemGrid.Item {
    let indexValue: Int
    override var index: Int {
        return self.indexValue
    }
    let localMonthTimestamp: Int32
    let peer: PeerReference
    let story: EngineStoryItem

    override var id: AnyHashable {
        return AnyHashable(self.story.id)
    }

    override var tag: Int32 {
        return self.localMonthTimestamp
    }

    override var holeAnchor: SparseItemGrid.HoleAnchor {
        return VisualMediaHoleAnchor(index: self.index, storyId: self.story.id, localMonthTimestamp: self.localMonthTimestamp)
    }
    
    init(index: Int, peer: PeerReference, story: EngineStoryItem, localMonthTimestamp: Int32) {
        self.indexValue = index
        self.peer = peer
        self.story = story
        self.localMonthTimestamp = localMonthTimestamp
    }
}

private struct Month: Equatable {
    var packedValue: Int32

    init(packedValue: Int32) {
        self.packedValue = packedValue
    }

    init(localTimestamp: Int32) {
        var time: time_t = time_t(localTimestamp)
        var timeinfo: tm = tm()
        gmtime_r(&time, &timeinfo)

        let year = UInt32(timeinfo.tm_year)
        let month = UInt32(timeinfo.tm_mon)

        self.packedValue = Int32(bitPattern: year | (month << 16))
    }

    var year: Int32 {
        return Int32(bitPattern: (UInt32(bitPattern: self.packedValue) >> 0) & 0xffff)
    }

    var month: Int32 {
        return Int32(bitPattern: (UInt32(bitPattern: self.packedValue) >> 16) & 0xffff)
    }
}

private let durationFont = Font.regular(12.0)
private let minDurationImage: UIImage = {
    let image = generateImage(CGSize(width: 20.0, height: 20.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(white: 0.0, alpha: 0.5).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        if let image = UIImage(bundleImageName: "Chat/GridPlayIcon") {
            UIGraphicsPushContext(context)
            image.draw(in: CGRect(origin: CGPoint(x: (size.width - image.size.width) / 2.0, y: (size.height - image.size.height) / 2.0), size: image.size))
            UIGraphicsPopContext()
        }
    })
    return image!
}()

private final class DurationLayer: CALayer {
    override init() {
        super.init()

        self.contentsGravity = .topRight
        self.contentsScale = UIScreenScale
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }

    func update(duration: Int32, isMin: Bool) {
        if isMin {
            self.contents = minDurationImage.cgImage
        } else {
            let string = NSAttributedString(string: stringForDuration(duration), font: durationFont, textColor: .white)
            let bounds = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
            let textSize = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
            let sideInset: CGFloat = 6.0
            let verticalInset: CGFloat = 2.0
            let image = generateImage(CGSize(width: textSize.width + sideInset * 2.0, height: textSize.height + verticalInset * 2.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))

                context.setFillColor(UIColor(white: 0.0, alpha: 0.5).cgColor)
                context.setBlendMode(.copy)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                context.fill(CGRect(origin: CGPoint(x: size.height / 2.0, y: 0.0), size: CGSize(width: size.width - size.height, height: size.height)))

                context.setBlendMode(.normal)
                UIGraphicsPushContext(context)
                string.draw(in: bounds.offsetBy(dx: sideInset, dy: verticalInset))
                UIGraphicsPopContext()
            })
            self.contents = image?.cgImage
        }
    }
}

private protocol ItemLayer: SparseItemGridLayer {
    var item: VisualMediaItem? { get set }
    var durationLayer: DurationLayer? { get set }
    var minFactor: CGFloat { get set }
    var selectionLayer: GridMessageSelectionLayer? { get set }
    var disposable: Disposable? { get set }

    var hasContents: Bool { get set }
    func setSpoilerContents(_ contents: Any?)
    
    func updateDuration(duration: Int32?, isMin: Bool, minFactor: CGFloat)
    func updateSelection(theme: CheckNodeTheme, isSelected: Bool?, animated: Bool)
    func updateHasSpoiler(hasSpoiler: Bool)
    
    func bind(item: VisualMediaItem)
    func unbind()
}

private final class GenericItemLayer: CALayer, ItemLayer {
    var item: VisualMediaItem?
    var durationLayer: DurationLayer?
    var minFactor: CGFloat = 1.0
    var selectionLayer: GridMessageSelectionLayer?
    var dustLayer: MediaDustLayer?
    var disposable: Disposable?

    var hasContents: Bool = false

    override init() {
        super.init()

        self.contentsGravity = .resize
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
    }
    
    func getContents() -> Any? {
        return self.contents
    }
    
    func setContents(_ contents: Any?) {
        if let image = contents as? UIImage {
            self.contents = image.cgImage
        }
    }
    
    func setSpoilerContents(_ contents: Any?) {
        if let image = contents as? UIImage {
            self.dustLayer?.contents = image.cgImage
        }
    }

    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }

    func bind(item: VisualMediaItem) {
        self.item = item
    }

    func updateDuration(duration: Int32?, isMin: Bool, minFactor: CGFloat) {
        self.minFactor = minFactor

        if let duration = duration {
            if let durationLayer = self.durationLayer {
                durationLayer.update(duration: duration, isMin: isMin)
            } else {
                let durationLayer = DurationLayer()
                durationLayer.update(duration: duration, isMin: isMin)
                self.addSublayer(durationLayer)
                durationLayer.frame = CGRect(origin: CGPoint(x: self.bounds.width - 3.0, y: self.bounds.height - 3.0), size: CGSize())
                durationLayer.transform = CATransform3DMakeScale(minFactor, minFactor, 1.0)
                self.durationLayer = durationLayer
            }
        } else if let durationLayer = self.durationLayer {
            self.durationLayer = nil
            durationLayer.removeFromSuperlayer()
        }
    }

    func updateSelection(theme: CheckNodeTheme, isSelected: Bool?, animated: Bool) {
        if let isSelected = isSelected {
            if let selectionLayer = self.selectionLayer {
                selectionLayer.updateSelected(isSelected, animated: animated)
            } else {
                let selectionLayer = GridMessageSelectionLayer(theme: theme)
                selectionLayer.updateSelected(isSelected, animated: false)
                self.selectionLayer = selectionLayer
                self.addSublayer(selectionLayer)
                if !self.bounds.isEmpty {
                    selectionLayer.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    selectionLayer.updateLayout(size: self.bounds.size)
                    if animated {
                        selectionLayer.animateIn()
                    }
                }
            }
        } else if let selectionLayer = self.selectionLayer {
            self.selectionLayer = nil
            if animated {
                selectionLayer.animateOut { [weak selectionLayer] in
                    selectionLayer?.removeFromSuperlayer()
                }
            } else {
                selectionLayer.removeFromSuperlayer()
            }
        }
    }
    
    func updateHasSpoiler(hasSpoiler: Bool) {
        if hasSpoiler {
            if let _ = self.dustLayer {
            } else {
                let dustLayer = MediaDustLayer()
                self.dustLayer = dustLayer
                self.addSublayer(dustLayer)
                if !self.bounds.isEmpty {
                    dustLayer.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    dustLayer.updateLayout(size: self.bounds.size)
                }
            }
        } else if let dustLayer = self.dustLayer {
            self.dustLayer = nil
            dustLayer.removeFromSuperlayer()
        }
    }

    func unbind() {
        self.item = nil
    }

    func needsShimmer() -> Bool {
        return !self.hasContents
    }

    func update(size: CGSize, insets: UIEdgeInsets, displayItem: SparseItemGridDisplayItem, binding: SparseItemGridBinding, item: SparseItemGrid.Item?) {
        if let durationLayer = self.durationLayer {
            durationLayer.frame = CGRect(origin: CGPoint(x: size.width - 3.0, y: size.height - 3.0), size: CGSize())
        }
        
        if let binding = binding as? SparseItemGridBindingImpl, let item = item as? VisualMediaItem, let previousItem = self.item, previousItem.story.media.id != item.story.media.id {
            binding.bindLayers(items: [item], layers: [displayItem], size: size, insets: insets, synchronous: .none)
        }
    }
}

private final class CaptureProtectedItemLayer: AVSampleBufferDisplayLayer, ItemLayer {
    var item: VisualMediaItem?
    var durationLayer: DurationLayer?
    var minFactor: CGFloat = 1.0
    var selectionLayer: GridMessageSelectionLayer?
    var dustLayer: MediaDustLayer?
    var disposable: Disposable?

    var hasContents: Bool = false

    override init() {
        super.init()
        
        self.contentsGravity = .resize
        if #available(iOS 13.0, *) {
            self.preventsCapture = true
            self.preventsDisplaySleepDuringVideoPlayback = false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
    }

    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }
    
    private var layerContents: Any?
    func getContents() -> Any? {
        return self.layerContents
    }
    
    func setContents(_ contents: Any?) {
        self.layerContents = contents
        
        if let image = contents as? UIImage {
            self.layerContents = image.cgImage
            if let cmSampleBuffer = image.cmSampleBuffer {
                self.enqueue(cmSampleBuffer)
            }
        }
    }
    
    func setSpoilerContents(_ contents: Any?) {
        if let image = contents as? UIImage {
            self.dustLayer?.contents = image.cgImage
        }
    }

    func bind(item: VisualMediaItem) {
        self.item = item
    }
    
    func updateDuration(duration: Int32?, isMin: Bool, minFactor: CGFloat) {
        self.minFactor = minFactor

        if let duration = duration {
            if let durationLayer = self.durationLayer {
                durationLayer.update(duration: duration, isMin: isMin)
            } else {
                let durationLayer = DurationLayer()
                durationLayer.update(duration: duration, isMin: isMin)
                self.addSublayer(durationLayer)
                durationLayer.frame = CGRect(origin: CGPoint(x: self.bounds.width - 3.0, y: self.bounds.height - 3.0), size: CGSize())
                durationLayer.transform = CATransform3DMakeScale(minFactor, minFactor, 1.0)
                self.durationLayer = durationLayer
            }
        } else if let durationLayer = self.durationLayer {
            self.durationLayer = nil
            durationLayer.removeFromSuperlayer()
        }
    }

    func updateSelection(theme: CheckNodeTheme, isSelected: Bool?, animated: Bool) {
        if let isSelected = isSelected {
            if let selectionLayer = self.selectionLayer {
                selectionLayer.updateSelected(isSelected, animated: animated)
            } else {
                let selectionLayer = GridMessageSelectionLayer(theme: theme)
                selectionLayer.updateSelected(isSelected, animated: false)
                self.selectionLayer = selectionLayer
                self.addSublayer(selectionLayer)
                if !self.bounds.isEmpty {
                    selectionLayer.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    selectionLayer.updateLayout(size: self.bounds.size)
                    if animated {
                        selectionLayer.animateIn()
                    }
                }
            }
        } else if let selectionLayer = self.selectionLayer {
            self.selectionLayer = nil
            if animated {
                selectionLayer.animateOut { [weak selectionLayer] in
                    selectionLayer?.removeFromSuperlayer()
                }
            } else {
                selectionLayer.removeFromSuperlayer()
            }
        }
    }
    
    func updateHasSpoiler(hasSpoiler: Bool) {
        if hasSpoiler {
            if let _ = self.dustLayer {
            } else {
                let dustLayer = MediaDustLayer()
                self.dustLayer = dustLayer
                self.addSublayer(dustLayer)
                if !self.bounds.isEmpty {
                    dustLayer.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    dustLayer.updateLayout(size: self.bounds.size)
                }
            }
        } else if let dustLayer = self.dustLayer {
            self.dustLayer = nil
            dustLayer.removeFromSuperlayer()
        }
    }

    func unbind() {
        self.item = nil
    }

    func needsShimmer() -> Bool {
        return !self.hasContents
    }

    func update(size: CGSize, insets: UIEdgeInsets, displayItem: SparseItemGridDisplayItem, binding: SparseItemGridBinding, item: SparseItemGrid.Item?) {
        if let durationLayer = self.durationLayer {
            durationLayer.frame = CGRect(origin: CGPoint(x: size.width - 3.0, y: size.height - 3.0), size: CGSize())
        }
    }
}

private final class ItemTransitionView: UIView {
    private weak var itemLayer: ItemLayer?
    private var copyDurationLayer: SimpleLayer?
    
    private var durationLayerBottomLeftPosition: CGPoint?
    
    init(itemLayer: ItemLayer?) {
        self.itemLayer = itemLayer
        
        super.init(frame: CGRect())
        
        if let itemLayer {
            self.layer.contents = itemLayer.contents
            self.layer.contentsRect = itemLayer.contentsRect
            
            if let durationLayer = itemLayer.durationLayer {
                let copyDurationLayer = SimpleLayer()
                copyDurationLayer.contents = durationLayer.contents
                copyDurationLayer.contentsRect = durationLayer.contentsRect
                copyDurationLayer.contentsGravity = durationLayer.contentsGravity
                copyDurationLayer.contentsScale = durationLayer.contentsScale
                copyDurationLayer.frame = durationLayer.frame
                self.layer.addSublayer(copyDurationLayer)
                self.copyDurationLayer = copyDurationLayer
                
                self.durationLayerBottomLeftPosition = CGPoint(x: itemLayer.bounds.width - durationLayer.frame.maxX, y: itemLayer.bounds.height - durationLayer.frame.maxY)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(state: StoryContainerScreen.TransitionState, transition: Transition) {
        let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
        
        if let copyDurationLayer = self.copyDurationLayer, let durationLayerBottomLeftPosition = self.durationLayerBottomLeftPosition {
            transition.setFrame(layer: copyDurationLayer, frame: CGRect(origin: CGPoint(x: size.width - durationLayerBottomLeftPosition.x - copyDurationLayer.bounds.width, y: size.height - durationLayerBottomLeftPosition.y - copyDurationLayer.bounds.height), size: copyDurationLayer.bounds.size))
        }
    }
}

private final class SparseItemGridBindingImpl: SparseItemGridBinding {
    let context: AccountContext
    let chatLocation: ChatLocation
    let directMediaImageCache: DirectMediaImageCache
    let captureProtected: Bool
    var strings: PresentationStrings
    var chatPresentationData: ChatPresentationData
    var checkNodeTheme: CheckNodeTheme

    var itemInteraction: VisualMediaItemInteraction?
    var loadHoleImpl: ((SparseItemGrid.HoleAnchor, SparseItemGrid.HoleLocation) -> Signal<Never, NoError>)?
    var onTapImpl: ((VisualMediaItem, CALayer, CGPoint) -> Void)?
    var onTagTapImpl: (() -> Void)?
    var didScrollImpl: (() -> Void)?
    var coveringInsetOffsetUpdatedImpl: ((ContainedViewLayoutTransition) -> Void)?
    var onBeginFastScrollingImpl: (() -> Void)?
    var getShimmerColorsImpl: (() -> SparseItemGrid.ShimmerColors)?
    var updateShimmerLayersImpl: ((SparseItemGridDisplayItem) -> Void)?
    
    var revealedSpoilerMessageIds = Set<MessageId>()

    private var shimmerImages: [CGFloat: UIImage] = [:]

    init(context: AccountContext, chatLocation: ChatLocation, directMediaImageCache: DirectMediaImageCache, captureProtected: Bool) {
        self.context = context
        self.chatLocation = chatLocation
        self.directMediaImageCache = directMediaImageCache
        self.captureProtected = false

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.strings = presentationData.strings

        let themeData = ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper)
        self.chatPresentationData = ChatPresentationData(theme: themeData, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners, animatedEmojiScale: 1.0)

        self.checkNodeTheme = CheckNodeTheme(theme: presentationData.theme, style: .overlay, hasInset: true)
    }

    func updatePresentationData(presentationData: PresentationData) {
        self.strings = presentationData.strings

        let themeData = ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper)
        self.chatPresentationData = ChatPresentationData(theme: themeData, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners, animatedEmojiScale: 1.0)

        self.checkNodeTheme = CheckNodeTheme(theme: presentationData.theme, style: .overlay, hasInset: true)
    }

    func getSeparatorColor() -> UIColor {
        return self.chatPresentationData.theme.theme.list.itemPlainSeparatorColor
    }

    func createLayer() -> SparseItemGridLayer? {
        if self.captureProtected {
            return CaptureProtectedItemLayer()
        } else {
            return GenericItemLayer()
        }
    }

    func createView() -> SparseItemGridView? {
        return nil
    }

    func createShimmerLayer() -> SparseItemGridShimmerLayer? {
        return nil
    }

    private static let widthSpecs: ([Int], [Int]) = {
        let list: [(Int, Int)] = [
            (50, 64),
            (100, 150),
            (140, 200),
            (Int.max, 280)
        ]
        return (list.map(\.0), list.map(\.1))
    }()

    func bindLayers(items: [SparseItemGrid.Item], layers: [SparseItemGridDisplayItem], size: CGSize, insets: UIEdgeInsets, synchronous: SparseItemGrid.Synchronous) {
        for i in 0 ..< items.count {
            guard let item = items[i] as? VisualMediaItem else {
                continue
            }

            let displayItem = layers[i]

            guard let layer = displayItem.layer as? ItemLayer else {
                continue
            }
            if layer.bounds.isEmpty {
                continue
            }
            
            var imageWidthSpec: Int = SparseItemGridBindingImpl.widthSpecs.1[0]
            for i in 0 ..< SparseItemGridBindingImpl.widthSpecs.0.count {
                if Int(layer.bounds.width) <= SparseItemGridBindingImpl.widthSpecs.0[i] {
                    imageWidthSpec = SparseItemGridBindingImpl.widthSpecs.1[i]
                    break
                }
            }
            
            let story = item.story
            let hasSpoiler = false
            layer.updateHasSpoiler(hasSpoiler: hasSpoiler)
            
            var selectedMedia: Media?
            if let image = story.media._asMedia() as? TelegramMediaImage {
                selectedMedia = image
            } else if let file = story.media._asMedia() as? TelegramMediaFile {
                selectedMedia = file
            }
            
            if let selectedMedia = selectedMedia {
                if let result = directMediaImageCache.getImage(peer: item.peer, story: story, media: selectedMedia, width: imageWidthSpec, aspectRatio: 0.81, possibleWidths: SparseItemGridBindingImpl.widthSpecs.1, includeBlurred: hasSpoiler || displayItem.blurLayer != nil, synchronous: synchronous == .full) {
                    if let image = result.image {
                        layer.setContents(image)
                        switch synchronous {
                        case .none:
                            layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak self, weak layer, weak displayItem] _ in
                                layer?.hasContents = true
                                if let displayItem = displayItem {
                                    self?.updateShimmerLayersImpl?(displayItem)
                                }
                            })
                        default:
                            layer.hasContents = true
                        }
                    }
                    if let image = result.blurredImage {
                        layer.setSpoilerContents(image)
                        
                        if let blurLayer = displayItem.blurLayer {
                            blurLayer.contentsGravity = .resizeAspectFill
                            blurLayer.contents = result.blurredImage?.cgImage
                        }
                    }
                    if let loadSignal = result.loadSignal {
                        layer.disposable?.dispose()
                        let startTimestamp = CFAbsoluteTimeGetCurrent()
                        layer.disposable = (loadSignal
                        |> deliverOnMainQueue).start(next: { [weak self, weak layer, weak displayItem] image in
                            guard let layer = layer else {
                                return
                            }
                            let deltaTime = CFAbsoluteTimeGetCurrent() - startTimestamp
                            let synchronousValue: Bool
                            switch synchronous {
                            case .none, .full:
                                synchronousValue = false
                            case .semi:
                                synchronousValue = deltaTime < 0.1
                            }
                            
                            if let contents = layer.getContents(), !synchronousValue {
                                let copyLayer = GenericItemLayer()
                                copyLayer.contents = contents
                                copyLayer.contentsRect = layer.contentsRect
                                copyLayer.frame = layer.bounds
                                if let durationLayer = layer.durationLayer {
                                    layer.insertSublayer(copyLayer, below: durationLayer)
                                } else {
                                    layer.addSublayer(copyLayer)
                                }
                                copyLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyLayer] _ in
                                    copyLayer?.removeFromSuperlayer()
                                })
                                
                                layer.setContents(image)
                                layer.hasContents = true
                                if let displayItem = displayItem {
                                    self?.updateShimmerLayersImpl?(displayItem)
                                }
                            } else {
                                layer.setContents(image)
                                
                                if !synchronousValue {
                                    layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak layer] _ in
                                        layer?.hasContents = true
                                        if let displayItem = displayItem {
                                            self?.updateShimmerLayersImpl?(displayItem)
                                        }
                                    })
                                } else {
                                    layer.hasContents = true
                                    if let displayItem = displayItem {
                                        self?.updateShimmerLayersImpl?(displayItem)
                                    }
                                }
                            }
                            
                            if let displayItem, let blurLayer = displayItem.blurLayer {
                                blurLayer.contentsGravity = .resizeAspectFill
                                blurLayer.contents = result.blurredImage?.cgImage
                            }
                        })
                    }
                }
                
                var duration: Int32?
                var isMin: Bool = false
                if let file = selectedMedia as? TelegramMediaFile, !file.isAnimated {
                    if let durationValue = file.duration {
                        duration = Int32(durationValue)
                    }
                    isMin = layer.bounds.width < 80.0
                }
                layer.updateDuration(duration: duration, isMin: isMin, minFactor: min(1.0, layer.bounds.height / 74.0))
            }
            
            var isSelected: Bool?
            if let selectedIds = self.itemInteraction?.selectedIds {
                isSelected = selectedIds.contains(story.id)
            }
            layer.updateSelection(theme: self.checkNodeTheme, isSelected: isSelected, animated: false)
            
            layer.bind(item: item)
        }
    }

    func unbindLayer(layer: SparseItemGridLayer) {
        guard let layer = layer as? ItemLayer else {
            return
        }
        layer.unbind()
    }

    func scrollerTextForTag(tag: Int32) -> String? {
        let month = Month(packedValue: tag)
        return stringForMonth(strings: self.strings, month: month.month, ofYear: month.year)
    }

    func loadHole(anchor: SparseItemGrid.HoleAnchor, at location: SparseItemGrid.HoleLocation) -> Signal<Never, NoError> {
        if let loadHoleImpl = self.loadHoleImpl {
            return loadHoleImpl(anchor, location)
        } else {
            return .never()
        }
    }

    func onTap(item: SparseItemGrid.Item, itemLayer: CALayer, point: CGPoint) {
        guard let item = item as? VisualMediaItem else {
            return
        }
        self.onTapImpl?(item, itemLayer, point)
    }

    func onTagTap() {
        self.onTagTapImpl?()
    }

    func didScroll() {
        self.didScrollImpl?()
    }

    func coveringInsetOffsetUpdated(transition: ContainedViewLayoutTransition) {
        self.coveringInsetOffsetUpdatedImpl?(transition)
    }

    func onBeginFastScrolling() {
        self.onBeginFastScrollingImpl?()
    }

    func getShimmerColors() -> SparseItemGrid.ShimmerColors {
        if let getShimmerColorsImpl = self.getShimmerColorsImpl {
            return getShimmerColorsImpl()
        } else {
            return SparseItemGrid.ShimmerColors(background: 0xffffff, foreground: 0xffffff)
        }
    }
}

public final class PeerInfoStoryPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public enum ContentType {
        case photoOrVideo
        case photo
        case video
    }

    public struct ZoomLevel {
        fileprivate var value: SparseItemGrid.ZoomLevel

        init(_ value: SparseItemGrid.ZoomLevel) {
            self.value = value
        }

        var rawValue: Int32 {
            return Int32(self.value.rawValue)
        }

        public init(rawValue: Int32) {
            self.value = SparseItemGrid.ZoomLevel(rawValue: Int(rawValue))
        }
    }
    
    private let context: AccountContext
    private let peerId: PeerId
    private let chatLocation: ChatLocation
    private let isSaved: Bool
    private let isArchive: Bool
    public private(set) var contentType: ContentType
    private var contentTypePromise: ValuePromise<ContentType>
    
    private let navigationController: () -> NavigationController?
    
    public weak var parentController: ViewController?

    private let contextGestureContainerNode: ContextControllerSourceNode
    private let itemGrid: SparseItemGrid
    private let itemGridBinding: SparseItemGridBindingImpl
    private let directMediaImageCache: DirectMediaImageCache
    private var items: SparseItemGrid.Items?
    private var didUpdateItemsOnce: Bool = false

    private var isDeceleratingAfterTracking = false
    
    private var _itemInteraction: VisualMediaItemInteraction?
    private var itemInteraction: VisualMediaItemInteraction {
        return self._itemInteraction!
    }
    
    public var selectedIds: Set<Int32> {
        return self.itemInteraction.selectedIds ?? Set()
    }
    private let selectedIdsPromise = ValuePromise<Set<Int32>>(Set())
    public var updatedSelectedIds: Signal<Set<Int32>, NoError> {
        return self.selectedIdsPromise.get()
    }
    
    public var selectedItems: [Int32: EngineStoryItem] {
        var result: [Int32: EngineStoryItem] = [:]
        for id in self.selectedIds {
            if let items = self.items {
                for item in items.items {
                    if let item = item as? VisualMediaItem {
                        if item.story.id == id {
                            result[id] = item.story
                        }
                    }
                }
            }
        }
        return result
    }
    
    public var isEmpty: Bool {
        if let items = self.items, items.items.count != 0 {
            return false
        } else {
            return true
        }
    }
    
    public private(set) var isSelectionModeActive: Bool
    
    private var currentParams: (size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    public var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    public var status: Signal<PeerInfoStatusData?, NoError> {
        self.statusPromise.get()
    }

    public var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    public var tabBarOffset: CGFloat {
        return self.itemGrid.coveringInsetOffset
    }
        
    private let listDisposable = MetaDisposable()
    private var hiddenMediaDisposable: Disposable?
    
    private var numberOfItemsToRequest: Int = 50
    private var isRequestingView: Bool = false
    private var isFirstHistoryView: Bool = true
    
    private var decelerationAnimator: ConstantDisplayLinkAnimator?
    
    private var animationTimer: SwiftSignalKit.Timer?

    public private(set) var calendarSource: SparseMessageCalendar?
    private var listSource: PeerStoryListContext

    public var openCurrentDate: (() -> Void)?
    public var paneDidScroll: (() -> Void)?
    public var emptyAction: (() -> Void)?

    private weak var currentGestureItem: SparseItemGridDisplayItem?

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private weak var pendingOpenListContext: PeerStoryListContentContextImpl?
    
    private var preloadArchiveListContext: PeerStoryListContext?
    
    private var emptyStateView: ComponentView<Empty>?
        
    public init(context: AccountContext, peerId: PeerId, chatLocation: ChatLocation, contentType: ContentType, captureProtected: Bool, isSaved: Bool, isArchive: Bool, navigationController: @escaping () -> NavigationController?, listContext: PeerStoryListContext?) {
        self.context = context
        self.peerId = peerId
        self.chatLocation = chatLocation
        self.contentType = contentType
        self.contentTypePromise = ValuePromise<ContentType>(contentType)
        self.navigationController = navigationController
        self.isSaved = isSaved
        self.isArchive = isArchive
        
        self.isSelectionModeActive = isArchive

        self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

        self.contextGestureContainerNode = ContextControllerSourceNode()
        self.itemGrid = SparseItemGrid(theme: self.presentationData.theme)
        self.directMediaImageCache = DirectMediaImageCache(account: context.account)

        self.itemGridBinding = SparseItemGridBindingImpl(
            context: context,
            chatLocation: .peer(id: peerId),
            directMediaImageCache: self.directMediaImageCache,
            captureProtected: captureProtected
        )

        self.listSource = listContext ?? PeerStoryListContext(account: context.account, peerId: peerId, isArchived: self.isArchive)
        self.calendarSource = nil
        
        super.init()

        let _ = (ApplicationSpecificNotice.getSharedMediaScrollingTooltip(accountManager: context.sharedContext.accountManager)
        |> deliverOnMainQueue).start(next: { [weak self] count in
            guard let strongSelf = self else {
                return
            }
            if count < 1 {
                strongSelf.itemGrid.updateScrollingAreaTooltip(tooltip: SparseItemGridScrollingArea.DisplayTooltip(animation: "anim_infotip", text: strongSelf.itemGridBinding.chatPresentationData.strings.SharedMedia_FastScrollTooltip, completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = ApplicationSpecificNotice.incrementSharedMediaScrollingTooltip(accountManager: strongSelf.context.sharedContext.accountManager, count: 1).start()
                }))
            }
        })

        self.itemGridBinding.loadHoleImpl = { [weak self] hole, location in
            guard let strongSelf = self else {
                return .never()
            }
            return strongSelf.loadHole(anchor: hole, at: location)
        }

        self.itemGridBinding.onTapImpl = { [weak self] item, itemLayer, point in
            guard let self else {
                return
            }
            
            if let selectedIds = self.itemInteraction.selectedIds, let itemLayer = itemLayer as? ItemLayer, let selectionLayer = itemLayer.selectionLayer {
                if selectionLayer.checkLayer.frame.insetBy(dx: -4.0, dy: -4.0).contains(point) {
                    self.itemInteraction.toggleSelection(item.story.id, !selectedIds.contains(item.story.id))
                    return
                }
            }
            
            if self.pendingOpenListContext != nil {
                return
            }
            
            //TODO:selection
            let listContext = PeerStoryListContentContextImpl(
                context: self.context,
                peerId: self.peerId,
                listContext: self.listSource,
                initialId: item.story.id
            )
            self.pendingOpenListContext = listContext
            self.itemGrid.isUserInteractionEnabled = false
            
            let _ = (listContext.state
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self, let navigationController = self.navigationController() else {
                    return
                }
                
                guard let pendingOpenListContext = self.pendingOpenListContext, pendingOpenListContext === listContext else {
                    return
                }
                self.pendingOpenListContext = nil
                self.itemGrid.isUserInteractionEnabled = true
                
                var transitionIn: StoryContainerScreen.TransitionIn?
                
                let story = item.story
                var foundItem: SparseItemGridDisplayItem?
                var foundItemLayer: SparseItemGridLayer?
                self.itemGrid.forEachVisibleItem { item in
                    guard let itemLayer = item.layer as? ItemLayer else {
                        return
                    }
                    foundItem = item
                    if let listItem = itemLayer.item, listItem.story.id == story.id {
                        foundItemLayer = itemLayer
                    }
                }
                if let foundItemLayer {
                    let itemRect = self.itemGrid.frameForItem(layer: foundItemLayer)
                    transitionIn = StoryContainerScreen.TransitionIn(
                        sourceView: self.view,
                        sourceRect: self.itemGrid.view.convert(itemRect, to: self.view),
                        sourceCornerRadius: 0.0,
                        sourceIsAvatar: false
                    )
                    
                    if let blurLayer = foundItem?.blurLayer {
                        let transition = Transition(animation: .curve(duration: 0.25, curve: .easeInOut))
                        transition.setAlpha(layer: blurLayer, alpha: 0.0)
                    }
                }
                
                let storyContainerScreen = StoryContainerScreen(
                    context: self.context,
                    content: listContext,
                    transitionIn: transitionIn,
                    transitionOut: { [weak self] _, itemId in
                        guard let self else {
                            return nil
                        }
                        
                        var foundItem: SparseItemGridDisplayItem?
                        var foundItemLayer: SparseItemGridLayer?
                        self.itemGrid.forEachVisibleItem { item in
                            guard let itemLayer = item.layer as? ItemLayer else {
                                return
                            }
                            foundItem = item
                            if let listItem = itemLayer.item, AnyHashable(listItem.story.id) == itemId {
                                foundItemLayer = itemLayer
                            }
                        }
                        if let foundItemLayer {
                            if let blurLayer = foundItem?.blurLayer {
                                let transition = Transition(animation: .curve(duration: 0.25, curve: .easeInOut))
                                transition.setAlpha(layer: blurLayer, alpha: 1.0)
                            }
                            
                            let itemRect = self.itemGrid.frameForItem(layer: foundItemLayer)
                            return StoryContainerScreen.TransitionOut(
                                destinationView: self.view,
                                transitionView: StoryContainerScreen.TransitionView(
                                    makeView: { [weak foundItemLayer] in
                                        return ItemTransitionView(itemLayer: foundItemLayer as? ItemLayer)
                                    },
                                    updateView: { view, state, transition in
                                        (view as? ItemTransitionView)?.update(state: state, transition: transition)
                                    },
                                    insertCloneTransitionView: { [weak self] view in
                                        guard let self else {
                                            return
                                        }
                                        self.addToTransitionSurface(view: view)
                                    }
                                ),
                                destinationRect: self.itemGrid.view.convert(itemRect, to: self.view),
                                destinationCornerRadius: 0.0,
                                destinationIsAvatar: false,
                                completed: {}
                            )
                        }
                        
                        return nil
                    }
                )
                
                self.hiddenMediaDisposable?.dispose()
                self.hiddenMediaDisposable = (storyContainerScreen.focusedItem
                |> deliverOnMainQueue).start(next: { [weak self] itemId in
                    guard let self else {
                        return
                    }
                    if let itemId {
                        self.itemInteraction.hiddenMedia = Set([itemId.id])
                    } else {
                        self.itemInteraction.hiddenMedia = Set()
                    }
                    self.updateHiddenItems()
                })
                
                navigationController.pushViewController(storyContainerScreen)
            })
        }

        self.itemGridBinding.onTagTapImpl = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openCurrentDate?()
        }

        self.itemGridBinding.didScrollImpl = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.paneDidScroll?()

            strongSelf.cancelPreviewGestures()
        }

        self.itemGridBinding.coveringInsetOffsetUpdatedImpl = { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.tabBarOffsetUpdated?(transition)
        }

        var processedOnBeginFastScrolling = false
        self.itemGridBinding.onBeginFastScrollingImpl = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if processedOnBeginFastScrolling {
                return
            }
            processedOnBeginFastScrolling = true

            let _ = (ApplicationSpecificNotice.getSharedMediaFastScrollingTooltip(accountManager: strongSelf.context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { count in
                guard let strongSelf = self else {
                    return
                }
                if count < 1 {
                    let _ = ApplicationSpecificNotice.incrementSharedMediaFastScrollingTooltip(accountManager: strongSelf.context.sharedContext.accountManager).start()

                    var currentNode: ASDisplayNode = strongSelf
                    var result: PeerInfoScreenNodeProtocol?
                    while true {
                        if let currentNode = currentNode as? PeerInfoScreenNodeProtocol {
                            result = currentNode
                            break
                        } else if let supernode = currentNode.supernode {
                            currentNode = supernode
                        } else {
                            break
                        }
                    }
                    if let result = result {
                        result.displaySharedMediaFastScrollingTooltip()
                    }
                }
            })
        }

        self.itemGridBinding.getShimmerColorsImpl = { [weak self] in
            guard let strongSelf = self, let presentationData = strongSelf.currentParams?.presentationData else {
                return SparseItemGrid.ShimmerColors(background: 0xffffff, foreground: 0xffffff)
            }

            let backgroundColor = presentationData.theme.list.mediaPlaceholderColor
            let foregroundColor = presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.6)

            return SparseItemGrid.ShimmerColors(background: backgroundColor.argb, foreground: foregroundColor.argb)
        }

        self.itemGridBinding.updateShimmerLayersImpl = { [weak self] layer in
            self?.itemGrid.updateShimmerLayers(item: layer)
        }

        self.itemGrid.cancelExternalContentGestures = { [weak self] in
            self?.contextGestureContainerNode.cancelGesture()
        }

        self.itemGrid.zoomLevelUpdated = { [weak self] zoomLevel in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf
            //let _ = updateVisualMediaStoredState(engine: strongSelf.context.engine, peerId: strongSelf.peerId, messageTag: strongSelf.stateTag, state: VisualMediaStoredState(zoomLevel: Int32(zoomLevel.rawValue))).start()
        }
        
        self._itemInteraction = VisualMediaItemInteraction(
            openItem: { [weak self] _ in
                guard let self else {
                    return
                }
                let _ = self
            },
            openItemContextActions: { [weak self] item, sourceNode, sourceRect, gesture in
                guard let self else {
                    return
                }
                let _ = self
            },
            toggleSelection: { [weak self] id, value in
                guard let self, let itemInteraction = self._itemInteraction else {
                    return
                }
                if var selectedIds = itemInteraction.selectedIds {
                    if value {
                        selectedIds.insert(id)
                    } else {
                        selectedIds.remove(id)
                    }
                    itemInteraction.selectedIds = selectedIds
                    self.selectedIdsPromise.set(selectedIds)
                    self.updateSelectedItems(animated: true)
                }
            }
        )
        //TODO:selection
        if isArchive || self.isSelectionModeActive {
            self._itemInteraction?.selectedIds = Set()
        }
        self.itemGridBinding.itemInteraction = self._itemInteraction

        self.contextGestureContainerNode.isGestureEnabled = false
        self.contextGestureContainerNode.addSubnode(self.itemGrid)
        self.addSubnode(self.contextGestureContainerNode)

        self.contextGestureContainerNode.shouldBegin = { [weak self] point in
            guard let strongSelf = self else {
                return false
            }
            guard let item = strongSelf.itemGrid.item(at: point) else {
                return false
            }

            if let result = strongSelf.view.hitTest(point, with: nil) {
                if result.asyncdisplaykit_node is SparseItemGridScrollingArea {
                    return false
                }
            }

            strongSelf.currentGestureItem = item

            return true
        }

        self.contextGestureContainerNode.customActivationProgress = { [weak self] progress, update in
            guard let strongSelf = self, let currentGestureItem = strongSelf.currentGestureItem else {
                return
            }
            guard let itemLayer = currentGestureItem.layer else {
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

        self.contextGestureContainerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let currentGestureItem = strongSelf.currentGestureItem else {
                return
            }
            strongSelf.currentGestureItem = nil

            guard let itemLayer = currentGestureItem.layer as? ItemLayer else {
                return
            }
            guard let story = itemLayer.item?.story else {
                return
            }
            let rect = strongSelf.itemGrid.frameForItem(layer: itemLayer)

            //TODO:context menu
            let _ = story
            let _ = rect
            let _ = gesture
            //strongSelf.chatControllerInteraction.openMessageContextActions(message, strongSelf, rect, gesture)

            strongSelf.itemGrid.cancelGestures()
        }
        
        self.statusPromise.set(.single(PeerInfoStatusData(text: "", isActivity: false, key: .stories)))

        /*self.storedStateDisposable = (visualMediaStoredState(engine: context.engine, peerId: peerId, messageTag: self.stateTag)
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if let value = value {
                strongSelf.updateZoomLevel(level: ZoomLevel(rawValue: value.zoomLevel))
            }
            strongSelf.requestHistoryAroundVisiblePosition(synchronous: false, reloadAtTop: false)
        })*/
        
        //TODO:hidden media
        /*self.hiddenMediaDisposable = context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds().start(next: { [weak self] ids in
            guard let strongSelf = self else {
                return
            }
            var hiddenMedia: [MessageId: [Media]] = [:]
            for id in ids {
                if case let .chat(accountId, messageId, media) = id, accountId == strongSelf.context.account.id {
                    hiddenMedia[messageId] = [media]
                }
            }
            strongSelf.itemInteraction.hiddenMedia = hiddenMedia

            if let items = strongSelf.items {
                for item in items.items {
                    if let item = item as? VisualMediaItem {
                        if hiddenMedia[item.message.id] != nil {
                            strongSelf.itemGrid.ensureItemVisible(index: item.index)
                            break
                        }
                    }
                }
            }

            strongSelf.updateHiddenMedia()
        })*/
        
        /*let animationTimer = SwiftSignalKit.Timer(timeout: 0.3, repeat: true, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            for (_, itemNode) in strongSelf.visibleMediaItems {
                itemNode.tick()
            }
        }, queue: .mainQueue())
        self.animationTimer = animationTimer
        animationTimer.start()*/

        /*self.statusPromise.set((self.contentTypePromise.get()
        |> distinctUntilChanged
        |> mapToSignal { contentType -> Signal<(ContentType, [MessageTags: Int32]), NoError> in
            var summaries: [MessageTags] = []
            switch contentType {
            case .photoOrVideo:
                summaries.append(.photo)
                summaries.append(.video)
            case .photo:
                summaries.append(.photo)
            case .video:
                summaries.append(.video)
            case .gifs:
                summaries.append(.gif)
            case .files:
                summaries.append(.file)
            case .voiceAndVideoMessages:
                summaries.append(.voiceOrInstantVideo)
            case .music:
                summaries.append(.music)
            }
            
            return context.engine.data.subscribe(EngineDataMap(
                summaries.map { TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: peerId, threadId: chatLocation.threadId, tag: $0) }
            ))
            |> map { summaries -> (ContentType, [MessageTags: Int32]) in
                var result: [MessageTags: Int32] = [:]
                for (key, count) in summaries {
                    result[key.tag] = count.flatMap(Int32.init) ?? 0
                }
                return (contentType, result)
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.0 != rhs.0 {
                return false
            }
            if lhs.1 != rhs.1 {
                return false
            }
            return true
        })
        |> map { contentType, dict -> PeerInfoStatusData? in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }

            switch contentType {
            case .photoOrVideo:
                let photoCount: Int32 = dict[.photo] ?? 0
                let videoCount: Int32 = dict[.video] ?? 0

                if photoCount != 0 && videoCount != 0 {
                    return PeerInfoStatusData(text: "\(presentationData.strings.SharedMedia_PhotoCount(Int32(photoCount))), \(presentationData.strings.SharedMedia_VideoCount(Int32(videoCount)))", isActivity: false, key: .media)
                } else if photoCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_PhotoCount(Int32(photoCount)), isActivity: false, key: .media)
                } else if videoCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_VideoCount(Int32(videoCount)), isActivity: false, key: .media)
                } else {
                    return nil
                }
            case .photo:
                let photoCount: Int32 = dict[.photo] ?? 0

                if photoCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_PhotoCount(Int32(photoCount)), isActivity: false, key: .media)
                } else {
                    return nil
                }
            case .video:
                let videoCount: Int32 = dict[.video] ?? 0

                if videoCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_VideoCount(Int32(videoCount)), isActivity: false, key: .media)
                } else {
                    return nil
                }
            case .gifs:
                let gifCount: Int32 = dict[.gif] ?? 0

                if gifCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_GifCount(Int32(gifCount)), isActivity: false, key: .gifs)
                } else {
                    return nil
                }
            case .files:
                let fileCount: Int32 = dict[.file] ?? 0

                if fileCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_FileCount(Int32(fileCount)), isActivity: false, key: .files)
                } else {
                    return nil
                }
            case .voiceAndVideoMessages:
                let itemCount: Int32 = dict[.voiceOrInstantVideo] ?? 0

                if itemCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_VoiceMessageCount(Int32(itemCount)), isActivity: false, key: .voice)
                } else {
                    return nil
                }
            case .music:
                let itemCount: Int32 = dict[.music] ?? 0

                if itemCount != 0 {
                    return PeerInfoStatusData(text: presentationData.strings.SharedMedia_MusicCount(Int32(itemCount)), isActivity: false, key: .music)
                } else {
                    return nil
                }
            }
        }))*/

        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.itemGridBinding.updatePresentationData(presentationData: presentationData)

            strongSelf.itemGrid.updatePresentationData(theme: presentationData.theme)
        })
        
        self.requestHistoryAroundVisiblePosition(synchronous: false, reloadAtTop: false)
        
        if peerId == context.account.peerId && !isArchive {
            self.preloadArchiveListContext = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: true)
        }
    }
    
    deinit {
        self.listDisposable.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.animationTimer?.invalidate()
        self.presentationDataDisposable?.dispose()
    }

    public func loadHole(anchor: SparseItemGrid.HoleAnchor, at location: SparseItemGrid.HoleLocation) -> Signal<Never, NoError> {
        let listSource = self.listSource
        return Signal { subscriber in
            listSource.loadMore(completion: {
                Queue.mainQueue().async {
                    subscriber.putCompletion()
                }
            })
            
            
            return EmptyDisposable
        }
        |> runOn(.mainQueue())
    }

    public func updateContentType(contentType: ContentType) {
    }

    public func updateZoomLevel(level: ZoomLevel) {
        self.itemGrid.setZoomLevel(level: level.value)

        //let _ = updateVisualMediaStoredState(engine: self.context.engine, peerId: self.peerId, messageTag: self.stateTag, state: VisualMediaStoredState(zoomLevel: level.rawValue)).start()
    }
    
    public func setIsSelectionModeActive(_ value: Bool) {
        if self.isSelectionModeActive != value {
            self.isSelectionModeActive = value
            
            if value {
                if self._itemInteraction?.selectedIds == nil {
                    self._itemInteraction?.selectedIds = Set()
                }
            } else {
                self._itemInteraction?.selectedIds = nil
            }
            
            self.selectedIdsPromise.set(self._itemInteraction?.selectedIds ?? Set())
            self.updateSelectedItems(animated: true)
        }
    }
    
    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    private func requestHistoryAroundVisiblePosition(synchronous: Bool, reloadAtTop: Bool) {
        if self.isRequestingView {
            return
        }
        self.isRequestingView = true
        var firstTime = true
        let queue = Queue()

        self.listDisposable.set((self.listSource.state
        |> deliverOn(queue)).start(next: { [weak self] state in
            guard let self else {
                return
            }
            
            let title: String
            if state.totalCount == 0 {
                title = ""
            } else {
                if self.isSaved {
                    title = self.presentationData.strings.StoryList_SubtitleSaved(Int32(state.totalCount))
                } else {
                    title = self.presentationData.strings.StoryList_SubtitleCount(Int32(state.totalCount))
                }
            }
            self.statusPromise.set(.single(PeerInfoStatusData(text: title, isActivity: false, key: .stories)))
            
            let timezoneOffset = Int32(TimeZone.current.secondsFromGMT())

            var mappedItems: [SparseItemGrid.Item] = []
            var mappedHoles: [SparseItemGrid.HoleAnchor] = []
            var totalCount: Int = 0
            if let peerReference = state.peerReference {
                for item in state.items {
                    mappedItems.append(VisualMediaItem(
                        index: mappedItems.count,
                        peer: peerReference,
                        story: item,
                        localMonthTimestamp: Month(localTimestamp: item.timestamp + timezoneOffset).packedValue
                    ))
                }
                if mappedItems.count < state.totalCount, let lastItem = state.items.last, let loadMoreToken = state.loadMoreToken {
                    mappedHoles.append(VisualMediaHoleAnchor(index: mappedItems.count, storyId: Int32(loadMoreToken), localMonthTimestamp: Month(localTimestamp: lastItem.timestamp + timezoneOffset).packedValue))
                }
            }
            totalCount = state.totalCount
            totalCount = max(mappedItems.count, totalCount)
            
            if totalCount == 0 && state.loadMoreToken != nil && !state.isCached {
                totalCount = 100
            }

            Queue.mainQueue().async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                var headerText: String?
                if strongSelf.isArchive && !mappedItems.isEmpty {
                    headerText = strongSelf.presentationData.strings.StoryList_ArchiveDescription
                }

                let items = SparseItemGrid.Items(
                    items: mappedItems,
                    holeAnchors: mappedHoles,
                    count: totalCount,
                    itemBinding: strongSelf.itemGridBinding,
                    headerText: headerText,
                    snapTopInset: false
                )

                let currentSynchronous = synchronous && firstTime
                let currentReloadAtTop = reloadAtTop && firstTime
                firstTime = false
                strongSelf.updateHistory(items: items, synchronous: currentSynchronous, reloadAtTop: currentReloadAtTop)
                strongSelf.isRequestingView = false
            }
        }))
    }
    
    private func updateHistory(items: SparseItemGrid.Items, synchronous: Bool, reloadAtTop: Bool) {
        self.items = items

        if let (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData) = self.currentParams {
            var gridSnapshot: UIView?
            if reloadAtTop {
                gridSnapshot = self.itemGrid.view.snapshotView(afterScreenUpdates: false)
            }
            self.update(size: size, topInset: topInset, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: false, transition: .immediate)
            self.updateSelectedItems(animated: false)
            if let gridSnapshot = gridSnapshot {
                self.view.addSubview(gridSnapshot)
                gridSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak gridSnapshot] _ in
                    gridSnapshot?.removeFromSuperview()
                })
            }
        }

        if !self.didSetReady {
            self.didSetReady = true
            self.ready.set(.single(true))
        }
    }
    
    public func scrollToTop() -> Bool {
        return self.itemGrid.scrollToTop()
    }

    public func hitTestResultForScrolling() -> UIView? {
        return self.itemGrid.hitTestResultForScrolling()
    }

    public func brieflyDisableTouchActions() {
        self.itemGrid.brieflyDisableTouchActions()
    }
    
    public func findLoadedMessage(id: MessageId) -> Message? {
        return nil
    }
    
    public func updateHiddenMedia() {
        //TODO:updateHiddenMedia
        /*self.itemGrid.forEachVisibleItem { item in
            guard let itemLayer = item.layer as? ItemLayer else {
                return
            }
            if let item = itemLayer.item {
                if self.itemInteraction.hiddenMedia[item.message.id] != nil {
                    itemLayer.isHidden = true
                    itemLayer.updateHasSpoiler(hasSpoiler: false)
                    self.itemGridBinding.revealedSpoilerMessageIds.insert(item.message.id)
                } else {
                    itemLayer.isHidden = false
                }
            } else {
                itemLayer.isHidden = false
            }
        }*/
    }
    
    public func transferVelocity(_ velocity: CGFloat) {
        self.itemGrid.transferVelocity(velocity)
    }
    
    public func cancelPreviewGestures() {
    }
    
    public func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
        
        /*var foundItemLayer: SparseItemGridLayer?
        self.itemGrid.forEachVisibleItem { item in
            guard let itemLayer = item.layer as? ItemLayer else {
                return
            }
            if let item = itemLayer.item, item.message.id == messageId {
                foundItemLayer = itemLayer
            }
        }
        if let itemLayer = foundItemLayer {
            let itemFrame = self.view.convert(self.itemGrid.frameForItem(layer: itemLayer), from: self.itemGrid.view)
            let proxyNode = ASDisplayNode()
            proxyNode.frame = itemFrame
            if let contents = itemLayer.getContents() {
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
        return nil*/
    }
    
    public func addToTransitionSurface(view: UIView) {
        self.itemGrid.addToTransitionSurface(view: view)
    }
    
    private var gridSelectionGesture: MediaPickerGridSelectionGesture<Int32>?
    
    override public func didLoad() {
        super.didLoad()
        
        /*let selectionRecognizer = MediaListSelectionRecognizer(target: self, action: #selector(self.selectionPanGesture(_:)))
        selectionRecognizer.shouldBegin = {
            return true
        }
        self.view.addGestureRecognizer(selectionRecognizer)*/
    }
    
    private var selectionPanState: (selecting: Bool, initialMessageId: EngineMessage.Id, toggledMessageIds: [[EngineMessage.Id]])?
    private var selectionScrollActivationTimer: SwiftSignalKit.Timer?
    private var selectionScrollDisplayLink: ConstantDisplayLinkAnimator?
    private var selectionScrollDelta: CGFloat?
    private var selectionLastLocation: CGPoint?
    
    private func storyAtPoint(_ location: CGPoint) -> StoryViewList.Item? {
        return nil
    }
    
    @objc private func selectionPanGesture(_ recognizer: UIGestureRecognizer) -> Void {
        //TODO:selection
        /*let location = recognizer.location(in: self.view)
        switch recognizer.state {
            case .began:
                if let message = self.messageAtPoint(location) {
                    let selecting = !(self.chatControllerInteraction.selectionState?.selectedIds.contains(message.id) ?? false)
                    self.selectionPanState = (selecting, message.id, [])
                    self.chatControllerInteraction.toggleMessagesSelection([message.id], selecting)
                }
            case .changed:
                self.handlePanSelection(location: location)
                self.selectionLastLocation = location
            case .ended, .failed, .cancelled:
                self.selectionPanState = nil
                self.selectionScrollDisplayLink = nil
                self.selectionScrollActivationTimer?.invalidate()
                self.selectionScrollActivationTimer = nil
                self.selectionScrollDelta = nil
                self.selectionLastLocation = nil
                self.selectionScrollSkipUpdate = false
            case .possible:
                break
            @unknown default:
                fatalError()
        }*/
    }
    
    private func handlePanSelection(location: CGPoint) {
    }
    
    private var selectionScrollSkipUpdate = false
    private func setupSelectionScrolling() {
        self.selectionScrollDisplayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
            self?.selectionScrollActivationTimer = nil
            if let strongSelf = self, let delta = strongSelf.selectionScrollDelta {
                let distance: CGFloat = 15.0 * min(1.0, 0.15 + abs(delta * delta))
                let direction: ListViewScrollDirection = delta > 0.0 ? .up : .down
                let _ = strongSelf.itemGrid.scrollWithDelta(direction == .up ? -distance : distance)
                
                if let location = strongSelf.selectionLastLocation {
                    if !strongSelf.selectionScrollSkipUpdate {
                        strongSelf.handlePanSelection(location: location)
                    }
                    strongSelf.selectionScrollSkipUpdate = !strongSelf.selectionScrollSkipUpdate
                }
            }
        })
        self.selectionScrollDisplayLink?.isPaused = false
    }
    
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        /*let location = gestureRecognizer.location(in: gestureRecognizer.view)
        if location.x < 44.0 {
            return false
        }*/
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.state != .failed, let otherGestureRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer {
            let _ = otherGestureRecognizer
            //otherGestureRecognizer.isEnabled = false
            //otherGestureRecognizer.isEnabled = true
            return true
        } else {
            return false
        }
    }
    
    public func clearSelection() {
        self.itemInteraction.selectedIds = Set()
        self.selectedIdsPromise.set(Set())
        self.updateSelectedItems(animated: true)
    }
    
    public func updateSelectedMessages(animated: Bool) {
    }
    
    private func updateSelectedItems(animated: Bool) {
        self.itemGrid.forEachVisibleItem { item in
            guard let itemLayer = item.layer as? ItemLayer, let item = itemLayer.item else {
                return
            }
            itemLayer.updateSelection(theme: self.itemGridBinding.checkNodeTheme, isSelected: self.itemInteraction.selectedIds?.contains(item.story.id), animated: animated)
        }

        let isSelecting = self._itemInteraction?.selectedIds != nil
        self.itemGrid.pinchEnabled = !isSelecting
        
        var enableDismissGesture = true
        if let items = self.items, items.items.isEmpty {
        } else if isSelecting {
            enableDismissGesture = false
        }
        self.view.disablesInteractiveTransitionGestureRecognizer = !enableDismissGesture
        
        if isSelecting {
            if self.gridSelectionGesture == nil {
                let selectionGesture = MediaPickerGridSelectionGesture<Int32>()
                selectionGesture.delegate = self
                selectionGesture.sideInset = 44.0
                selectionGesture.updateIsScrollEnabled = { [weak self] isEnabled in
                    self?.itemGrid.isScrollEnabled = isEnabled
                }
                selectionGesture.itemAt = { [weak self] point in
                    if let strongSelf = self, let itemLayer = strongSelf.itemGrid.item(at: point)?.layer as? ItemLayer, let storyId = itemLayer.item?.story.id {
                        return (storyId, strongSelf._itemInteraction?.selectedIds?.contains(storyId) ?? false)
                    } else {
                        return nil
                    }
                }
                selectionGesture.updateSelection = { [weak self] storyId, selected in
                    if let strongSelf = self {
                        strongSelf._itemInteraction?.toggleSelection(storyId, selected)
                    }
                }
                self.itemGrid.view.addGestureRecognizer(selectionGesture)
                self.gridSelectionGesture = selectionGesture
            }
        } else if let gridSelectionGesture = self.gridSelectionGesture {
            self.itemGrid.view.removeGestureRecognizer(gridSelectionGesture)
            self.gridSelectionGesture = nil
        }
    }
    
    private func updateHiddenItems() {
        self.itemGrid.forEachVisibleItem { itemValue in
            guard let itemLayer = itemValue.layer as? ItemLayer, let item = itemLayer.item else {
                return
            }
            let itemHidden = self.itemInteraction.hiddenMedia.contains(item.story.id)
            itemLayer.isHidden = itemHidden
            
            if let blurLayer = itemValue.blurLayer {
                let transition = Transition.immediate
                if itemHidden {
                    transition.setAlpha(layer: blurLayer, alpha: 0.0)
                } else {
                    transition.setAlpha(layer: blurLayer, alpha: 1.0)
                }
            }
        }
    }
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)

        transition.updateFrame(node: self.contextGestureContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        
        if let items = self.items, items.items.isEmpty, items.count == 0 {
            let emptyStateView: ComponentView<Empty>
            var emptyStateTransition = Transition(transition)
            if let current = self.emptyStateView {
                emptyStateView = current
            } else {
                emptyStateTransition = .immediate
                emptyStateView = ComponentView()
                self.emptyStateView = emptyStateView
            }
            let emptyStateSize = emptyStateView.update(
                transition: emptyStateTransition,
                component: AnyComponent(EmptyStateIndicatorComponent(
                    context: self.context,
                    theme: presentationData.theme,
                    animationName: "StoryListEmpty",
                    title: self.isArchive ? presentationData.strings.StoryList_ArchivedEmptyState_Title : presentationData.strings.StoryList_SavedEmptyState_Title,
                    text: self.isArchive ? presentationData.strings.StoryList_ArchivedEmptyState_Text : presentationData.strings.StoryList_SavedEmptyState_Text,
                    actionTitle: self.isArchive ? nil : presentationData.strings.StoryList_SavedEmptyAction,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.emptyAction?()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: size.height - topInset - bottomInset)
            )
            if let emptyStateComponentView = emptyStateView.view {
                if emptyStateComponentView.superview == nil {
                    self.view.addSubview(emptyStateComponentView)
                    if self.didUpdateItemsOnce {
                        emptyStateComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
                emptyStateTransition.setFrame(view: emptyStateComponentView, frame: CGRect(origin: CGPoint(x: floor((size.width - emptyStateSize.width) * 0.5), y: topInset), size: emptyStateSize))
            }
            if self.didUpdateItemsOnce {
                Transition(animation: .curve(duration: 0.2, curve: .easeInOut)).setBackgroundColor(view: self.view, color: presentationData.theme.list.blocksBackgroundColor)
            } else {
                self.view.backgroundColor = presentationData.theme.list.blocksBackgroundColor
            }
        } else {
            if let emptyStateView = self.emptyStateView {
                let subTransition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
                self.emptyStateView = nil
                
                if let emptyStateComponentView = emptyStateView.view {
                    subTransition.setAlpha(view: emptyStateComponentView, alpha: 0.0, completion: { [weak emptyStateComponentView] _ in
                        emptyStateComponentView?.removeFromSuperview()
                    })
                }
                
                subTransition.setBackgroundColor(view: self.view, color: presentationData.theme.list.blocksBackgroundColor)
            } else {
                self.view.backgroundColor = .clear
            }
        }

        transition.updateFrame(node: self.itemGrid, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        if let items = self.items {
            let wasFirstTime = !self.didUpdateItemsOnce
            self.didUpdateItemsOnce = true
            let fixedItemHeight: CGFloat?
            let isList = false
            switch self.contentType {
            default:
                fixedItemHeight = nil
            }
            
            let fixedItemAspect: CGFloat? = 0.81
            
            let gridTopInset = topInset
         
            self.itemGrid.pinchEnabled = items.count > 2
            self.itemGrid.update(size: size, insets: UIEdgeInsets(top: gridTopInset, left: sideInset, bottom:  bottomInset, right: sideInset), useSideInsets: !isList, scrollIndicatorInsets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: bottomInset, right: sideInset), lockScrollingAtTop: isScrollingLockedAtTop, fixedItemHeight: fixedItemHeight, fixedItemAspect: fixedItemAspect, items: items, theme: self.itemGridBinding.chatPresentationData.theme.theme, synchronous: wasFirstTime ? .full : .none)
        }
    }

    public func currentTopTimestamp() -> Int32? {
        var timestamp: Int32?
        self.itemGrid.forEachVisibleItem { item in
            guard let itemLayer = item.layer as? ItemLayer else {
                return
            }
            if let item = itemLayer.item {
                if let timestampValue = timestamp {
                    timestamp = max(timestampValue, item.story.timestamp)
                } else {
                    timestamp = item.story.timestamp
                }
            }
        }
        return timestamp
    }

    public func scrollToTimestamp(timestamp: Int32) {
        if let items = self.items, !items.items.isEmpty {
            var previousIndex: Int?
            for item in items.items {
                guard let item = item as? VisualMediaItem else {
                    continue
                }
                if item.story.timestamp <= timestamp {
                    break
                }
                previousIndex = item.index
            }
            if previousIndex == nil {
                previousIndex = (items.items[0] as? VisualMediaItem)?.index
            }
            if let index = previousIndex {
                self.itemGrid.scrollToItem(at: index)

                if let item = self.itemGrid.item(at: index) {
                    if let layer = item.layer as? ItemLayer {
                        Queue.mainQueue().after(0.1, { [weak layer] in
                            guard let layer = layer else {
                                return
                            }

                            let overlayLayer = SimpleLayer()
                            overlayLayer.backgroundColor = UIColor(white: 1.0, alpha: 0.6).cgColor
                            overlayLayer.frame = layer.bounds
                            layer.addSublayer(overlayLayer)
                            overlayLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.8, delay: 0.3, removeOnCompletion: false, completion: { [weak overlayLayer] _ in
                                overlayLayer?.removeFromSuperlayer()
                            })
                        })
                    }
                }
            }
        }
    }

    public func scrollToItem(index: Int) {
        guard let _ = self.items else {
            return
        }
        self.itemGrid.scrollToItem(at: index)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        /*if self.decelerationAnimator != nil {
            self.decelerationAnimator?.isPaused = true
            self.decelerationAnimator = nil
            
            return self.scrollNode.view
        }*/
        return result
    }

    public func availableZoomLevels() -> (decrement: ZoomLevel?, increment: ZoomLevel?) {
        let levels = self.itemGrid.availableZoomLevels()
        return (levels.decrement.flatMap(ZoomLevel.init), levels.increment.flatMap(ZoomLevel.init))
    }
}

private class MediaListSelectionRecognizer: UIPanGestureRecognizer {
    private let selectionGestureActivationThreshold: CGFloat = 5.0
    
    var recognized: Bool? = nil
    var initialLocation: CGPoint = CGPoint()
    
    public var shouldBegin: (() -> Bool)?
    
    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.minimumNumberOfTouches = 2
        self.maximumNumberOfTouches = 2
    }
    
    public override func reset() {
        super.reset()
        
        self.recognized = nil
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let shouldBegin = self.shouldBegin, !shouldBegin() {
            self.state = .failed
        } else {
            let touch = touches.first!
            self.initialLocation = touch.location(in: self.view)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = location.offsetBy(dx: -self.initialLocation.x, dy: -self.initialLocation.y)
        
        let touchesArray = Array(touches)
        if self.recognized == nil, touchesArray.count == 2 {
            if let firstTouch = touchesArray.first, let secondTouch = touchesArray.last {
                let firstLocation = firstTouch.location(in: self.view)
                let secondLocation = secondTouch.location(in: self.view)
                
                func distance(_ v1: CGPoint, _ v2: CGPoint) -> CGFloat {
                    let dx = v1.x - v2.x
                    let dy = v1.y - v2.y
                    return sqrt(dx * dx + dy * dy)
                }
                if distance(firstLocation, secondLocation) > 200.0 {
                    self.state = .failed
                }
            }
            if self.state != .failed && (abs(translation.y) >= selectionGestureActivationThreshold) {
                self.recognized = true
            }
        }
        
        if let recognized = self.recognized, recognized {
            super.touchesMoved(touches, with: event)
        }
    }
}
