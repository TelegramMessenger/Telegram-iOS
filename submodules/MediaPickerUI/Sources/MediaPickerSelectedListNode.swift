import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import LegacyComponents
import CheckNode
import MosaicLayout
import WallpaperBackgroundNode
import AccountContext
import ChatMessageBackground

private class MediaPickerSelectedItemNode: ASDisplayNode {
    let asset: TGMediaAsset
    private let interaction: MediaPickerInteraction?
    
    private let imageNode: ImageNode
    private var checkNode: InteractiveCheckNode?
    private var durationBackgroundNode: ASDisplayNode?
    private var durationTextNode: ImmediateTextNode?
    
    private var adjustmentsDisposable: Disposable?
    
    private var theme: PresentationTheme?
    
    private var validLayout: CGSize?
    
    var corners: CACornerMask = [] {
        didSet {
            if #available(iOS 13.0, *) {
                self.layer.cornerCurve = .circular
            }
            if #available(iOS 11.0, *) {
                self.layer.maskedCorners = corners
            }
        }
    }
    
    var radius: CGFloat = 0.0 {
        didSet {
            self.layer.cornerRadius = radius
        }
    }
    
    private var readyPromise = Promise<Bool>()
    fileprivate var ready: Signal<Bool, NoError> {
        return self.readyPromise.get()
    }
    
    private var videoDuration: Double?
    
    init(asset: TGMediaAsset, interaction: MediaPickerInteraction?) {
        self.imageNode = ImageNode()
        self.imageNode.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        self.imageNode.animateFirstTransition = false
        
        self.asset = asset
        self.interaction = interaction
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.imageNode)
        
        if asset.isVideo, let editingState = interaction?.editingState {
            func adjustmentsChangedSignal(editingState: TGMediaEditingContext) -> Signal<TGMediaEditAdjustments?, NoError> {
                return Signal { subscriber in
                    let disposable = editingState.adjustmentsSignal(for: asset).start(next: { next in
                        if let next = next as? TGMediaEditAdjustments {
                            subscriber.putNext(next)
                        } else if next == nil {
                            subscriber.putNext(nil)
                        }
                    }, error: nil, completed: {})
                    return ActionDisposable {
                        disposable?.dispose()
                    }
                }
            }
            
            self.adjustmentsDisposable = (adjustmentsChangedSignal(editingState: editingState)
            |> deliverOnMainQueue).start(next: { [weak self] adjustments in
                if let strongSelf = self {
                    let duration: Double
                    if let adjustments = adjustments as? TGVideoEditAdjustments, adjustments.trimApplied() {
                        duration = adjustments.trimEndValue - adjustments.trimStartValue
                    } else {
                        duration = asset.videoDuration
                    }
                    strongSelf.videoDuration = duration
                    
                    if let size = strongSelf.validLayout {
                        strongSelf.updateLayout(size: size, transition: .immediate)
                    }
                }
            })
        }
    }
    
    deinit {
        self.adjustmentsDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
    }
    
    @objc private func tap() {
        self.interaction?.openSelectedMedia(asset, self.imageNode.image)
    }
    
    func setup(size: CGSize) {
        let editingState = self.interaction?.editingState
        let editedSignal = Signal<UIImage?, NoError> { subscriber in
            if let editingState = editingState, let signal = editingState.thumbnailImageSignal(forIdentifier: self.asset.uniqueIdentifier) {
                let disposable = signal.start(next: { next in
                    if let image = next as? UIImage {
                        subscriber.putNext(image)
                    } else {
                        subscriber.putNext(nil)
                    }
                }, error: { _ in
                }, completed: nil)!
                
                return ActionDisposable {
                    disposable.dispose()
                }
            } else {
                return EmptyDisposable
            }
        }
        
        let dimensions: CGSize
        if let adjustments = self.interaction?.editingState.adjustments(for: self.asset), adjustments.cropApplied(forAvatar: false) {
            dimensions = adjustments.cropRect.size
        } else {
            dimensions = self.asset.dimensions
        }
        
        let scale = min(2.0, UIScreenScale)
        let scaledDimensions = dimensions.aspectFilled(CGSize(width: 320.0, height: 320.0))
        let targetSize = CGSize(width: scaledDimensions.width * scale, height: scaledDimensions.height * scale)
        
        let originalSignal = assetImage(asset: self.asset.backingAsset, targetSize: targetSize, exact: false)
        let imageSignal: Signal<UIImage?, NoError> = editedSignal
        |> mapToSignal { result in
            if let result = result {
                return .single(result)
            } else {
                return originalSignal
            }
        }
        self.imageNode.setSignal(imageSignal)
        self.readyPromise.set(self.imageNode.contentReady)
    }
    
    func updateSelectionState() {
        if self.checkNode == nil, let _ = self.interaction?.selectionState, let theme = self.theme {
            let checkNode = InteractiveCheckNode(theme: CheckNodeTheme(theme: theme, style: .overlay))
            checkNode.valueChanged = { [weak self] value in
                if let strongSelf = self, let interaction = strongSelf.interaction {
                    interaction.toggleSelection(strongSelf.asset, value, true)
                }
            }
            self.addSubnode(checkNode)
            self.checkNode = checkNode

            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate)
            }
        }
        
        if let interaction = self.interaction, let selectionState = interaction.selectionState, let identifier = self.asset.uniqueIdentifier {
            let selected = selectionState.isIdentifierSelected(identifier)
            let index = selectionState.index(of: self.asset)
            if index != NSNotFound {
                self.checkNode?.content = .counter(Int(index))
            }
            self.checkNode?.setSelected(selected, animated: false)
            
            if let checkNode = self.checkNode {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                transition.updateAlpha(node: checkNode, alpha: selectionState.count() < 2 ? 0.0 : 1.0)
            }
        }
    }
    
    func updateHiddenMedia() {
        let wasHidden = self.isHidden
        self.isHidden = self.interaction?.hiddenMediaId == asset.uniqueIdentifier
        if !self.isHidden && wasHidden {
            if let checkNode = self.checkNode, checkNode.alpha > 0.0 {
                checkNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            
            if let durationTextNode = self.durationTextNode, durationTextNode.alpha > 0.0 {
                durationTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            if let durationBackgroundNode = self.durationBackgroundNode, durationBackgroundNode.alpha > 0.0 {
                durationBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
    }
    
    func update(theme: PresentationTheme) {
        var updatedTheme = false
        if self.theme != theme {
            self.theme = theme
            updatedTheme = true
        }
        
        if updatedTheme {
            self.checkNode?.theme = CheckNodeTheme(theme: theme, style: .overlay)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let checkSize = CGSize(width: 29.0, height: 29.0)
        if let checkNode = self.checkNode {
            transition.updateFrame(node: checkNode, frame: CGRect(origin: CGPoint(x: size.width - checkSize.width - 3.0, y: 3.0), size: checkSize))
        }
        
        if let duration = self.videoDuration {
            let textNode: ImmediateTextNode
            let backgroundNode: ASDisplayNode
            if let currentTextNode = self.durationTextNode, let currentBackgroundNode = self.durationBackgroundNode {
                textNode = currentTextNode
                backgroundNode = currentBackgroundNode
            } else {
                backgroundNode = ASDisplayNode()
                backgroundNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.5)
                backgroundNode.cornerRadius = 9.0
                self.addSubnode(backgroundNode)
                self.durationBackgroundNode = backgroundNode
                
                textNode = ImmediateTextNode()
                textNode.displaysAsynchronously = false
                self.addSubnode(textNode)
                self.durationTextNode = textNode
            }
            
            textNode.attributedText = NSAttributedString(string: stringForDuration(Int32(duration)), font: Font.with(size: 11.0, design: .regular, weight: .regular, traits: .monospacedNumbers), textColor: .white)
            
            let textSize = textNode.updateLayout(size)
            let backgroundFrame = CGRect(x: 6.0, y: 6.0, width: ceil(textSize.width) + 14.0, height: 18.0)
            backgroundNode.frame = backgroundFrame
            textNode.frame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floorToScreenPixels((backgroundFrame.size.width - textSize.width) / 2.0), y: backgroundFrame.minY + floorToScreenPixels((backgroundFrame.size.height - textSize.height) / 2.0)), size: textSize)
        } else {
            if let durationTextNode = self.durationTextNode {
                self.durationTextNode = nil
                durationTextNode.removeFromSupernode()
            }
            if let durationBackgroundNode = self.durationBackgroundNode {
                self.durationBackgroundNode = nil
                durationBackgroundNode.removeFromSupernode()
            }
        }
    }
    
    func transitionView() -> UIView {
        let view = self.imageNode.view.snapshotContentTree(unhide: true, keepTransform: true)!
        if #available(iOS 13.0, *) {
            view.layer.cornerCurve = self.layer.cornerCurve
        }
        if #available(iOS 11.0, *) {
            view.layer.maskedCorners = self.layer.maskedCorners
            view.layer.cornerRadius = self.layer.cornerRadius
        }
        view.frame = self.convert(self.bounds, to: nil)
        return view
    }
    
    func animateFrom(_ view: UIView) {
        view.alpha = 0.0
        
        let frame = view.convert(view.bounds, to: self.supernode?.view)
        let targetFrame = self.frame
        
        self.durationTextNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.durationBackgroundNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        self.updateLayout(size: frame.size, transition: .immediate)
        self.updateLayout(size: targetFrame.size, transition: .animated(duration: 0.25, curve: .spring))
        self.layer.animateFrame(from: frame, to: targetFrame, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak view] _ in
            view?.alpha = 1.0
        })
    }
    
    func animateTo(_ view: UIView, completion: @escaping (Bool) -> Void) {
        view.alpha = 0.0
        
        let frame = self.frame
        let targetFrame = view.convert(view.bounds, to: self.supernode?.view)
        
        let corners = self.corners
        
        self.durationTextNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.durationBackgroundNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        self.corners = []
        self.updateLayout(size: targetFrame.size, transition: .animated(duration: 0.25, curve: .spring))
        self.layer.animateFrame(from: frame, to: targetFrame, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak view, weak self] _ in
            view?.alpha = 1.0
            
            self?.durationTextNode?.layer.removeAllAnimations()
            self?.durationBackgroundNode?.layer.removeAllAnimations()
            
            var animateCheckNode = false
            if let strongSelf = self, let checkNode = strongSelf.checkNode, checkNode.alpha.isZero {
                animateCheckNode = true
            }
            completion(animateCheckNode)
                
            self?.corners = corners
            self?.updateLayout(size: frame.size, transition: .immediate)
            
            Queue.mainQueue().after(0.01) {
                self?.layer.removeAllAnimations()
            }
        })
    }
}

private class MessageBackgroundNode: ASDisplayNode {
    private let backgroundWallpaperNode: ChatMessageBubbleBackdrop
    private let backgroundNode: ChatMessageBackground
    private let shadowNode: ChatMessageShadowNode
    
    override init() {
        self.backgroundWallpaperNode = ChatMessageBubbleBackdrop()
        self.backgroundNode = ChatMessageBackground()
        self.shadowNode = ChatMessageShadowNode()

        super.init()
        
        self.addSubnode(self.backgroundWallpaperNode)
        self.addSubnode(self.backgroundNode)
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    
    func update(size: CGSize, theme: PresentationTheme, wallpaper: TelegramWallpaper, graphics: PrincipalThemeEssentialGraphics, wallpaperBackgroundNode: WallpaperBackgroundNode, transition: ContainedViewLayoutTransition) {
        
        self.backgroundNode.setType(type: .outgoing(.Extracted), highlighted: false, graphics: graphics, maskMode: false, hasWallpaper: wallpaper.hasWallpaper, transition: transition, backgroundNode: wallpaperBackgroundNode)
        self.backgroundWallpaperNode.setType(type: .outgoing(.Extracted), theme: ChatPresentationThemeData(theme: theme, wallpaper: wallpaper), essentialGraphics: graphics, maskMode: true, backgroundNode: wallpaperBackgroundNode)
        self.shadowNode.setType(type: .outgoing(.Extracted), hasWallpaper: wallpaper.hasWallpaper, graphics: graphics)
        
        let backgroundFrame = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.updateLayout(size: backgroundFrame.size, transition: transition)
        self.backgroundWallpaperNode.updateFrame(backgroundFrame, transition: transition)
        self.shadowNode.updateLayout(backgroundFrame: backgroundFrame, transition: transition)
        
        if let (rect, size) = self.absoluteRect {
            self.updateAbsoluteRect(rect, within: size)
        }
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        var backgroundWallpaperFrame = self.backgroundWallpaperNode.frame
        backgroundWallpaperFrame.origin.x += rect.minX
        backgroundWallpaperFrame.origin.y += rect.minY
        self.backgroundWallpaperNode.update(rect: backgroundWallpaperFrame, within: containerSize)
    }
}

final class MediaPickerSelectedListNode: ASDisplayNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let context: AccountContext
    
    fileprivate let wallpaperBackgroundNode: WallpaperBackgroundNode
    private let scrollNode: ASScrollNode
    private var backgroundNodes: [Int: MessageBackgroundNode] = [:]
    private var itemNodes: [String: MediaPickerSelectedItemNode] = [:]
    
    private var reorderFeedback: HapticFeedback?
    private var reorderNode: ReorderingItemNode?
    private var isReordering = false

    private var graphics: PrincipalThemeEssentialGraphics?
    
    var interaction: MediaPickerInteraction?
    
    private var validLayout: (size: CGSize, insets: UIEdgeInsets, items: [TGMediaSelectableItem], grouped: Bool, theme: PresentationTheme, wallpaper: TelegramWallpaper, bubbleCorners: PresentationChatBubbleCorners)?
    
    private var didSetReady = false
    private var ready = Promise<Bool>()
    
    init(context: AccountContext) {
        self.context = context
        self.wallpaperBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: true, useSharedAnimationPhase: false, useExperimentalImplementation: context.sharedContext.immediateExperimentalUISettings.experimentalBackground)
        self.wallpaperBackgroundNode.backgroundColor = .black
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        self.addSubnode(self.wallpaperBackgroundNode)
        self.addSubnode(self.scrollNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.scrollNode.view.delegate = self
        self.scrollNode.view.panGestureRecognizer.cancelsTouchesInView = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        
        self.view.addGestureRecognizer(ReorderingGestureRecognizer(shouldBegin: { [weak self] point in
            if let strongSelf = self, !strongSelf.scrollNode.view.isDragging && strongSelf.itemNodes.count > 1 {
                let point = strongSelf.view.convert(point, to: strongSelf.scrollNode.view)
                for (_, itemNode) in strongSelf.itemNodes {
                    if itemNode.frame.contains(point) {
                        return (true, true, itemNode)
                    }
                }
                return (false, false, nil)
            }
            return (false, false, nil)
        }, willBegin: { _ in

        }, began: { [weak self] itemNode in
            self?.beginReordering(itemNode: itemNode)
        }, ended: { [weak self] point in
            if let strongSelf = self {
                if var point = point {
                    point = strongSelf.view.convert(point, to: strongSelf.scrollNode.view)
                    strongSelf.endReordering(point: point)
                } else {
                    strongSelf.endReordering(point: nil)
                }
            }
        }, moved: { [weak self] offset in
            self?.updateReordering(offset: offset)
        }))
        
        Queue.mainQueue().after(0.1, {
            self.updateAbsoluteRects()
        })
    }
    
    var getTransitionView: (String ) -> (UIView, (Bool) -> Void)? = { _ in return nil }
    
    func animateIn(initiated: @escaping () -> Void, completion: @escaping () -> Void = {}) {
        let _ = (self.ready.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.alpha = 1.0
            initiated()
            
            strongSelf.wallpaperBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { _ in
                completion()
            })
            strongSelf.wallpaperBackgroundNode.layer.animateScale(from: 1.2, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            
            for (_, backgroundNode) in strongSelf.backgroundNodes {
                backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: 0.1)
            }
            
            for (identifier, itemNode) in strongSelf.itemNodes {
                if let (transitionView, _) = strongSelf.getTransitionView(identifier) {
                    itemNode.animateFrom(transitionView)
                } else {
                    itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                }
            }
            
            if let topNode = strongSelf.messageNodes?.first, !topNode.alpha.isZero {
                topNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: 0.1)
                topNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -30.0), to: CGPoint(), duration: 0.4, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            
            if let bottomNode = strongSelf.messageNodes?.last, !bottomNode.alpha.isZero {
                bottomNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: 0.1)
                bottomNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 30.0), to: CGPoint(), duration: 0.4, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        })
    }
    
    func animateOut(completion: @escaping () -> Void = {}) {
        self.wallpaperBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak self] _ in
            completion()
            
            if let strongSelf = self {
                Queue.mainQueue().after(0.01) {
                    for (_, backgroundNode) in strongSelf.backgroundNodes {
                        backgroundNode.layer.removeAllAnimations()
                    }
                    
                    for (_, itemNode) in strongSelf.itemNodes {
                        itemNode.layer.removeAllAnimations()
                    }
                    
                    strongSelf.messageNodes?.first?.layer.removeAllAnimations()
                    strongSelf.messageNodes?.last?.layer.removeAllAnimations()
                    
                    strongSelf.wallpaperBackgroundNode.layer.removeAllAnimations()
                }
            }
        })
        
        self.wallpaperBackgroundNode.layer.animateScale(from: 1.0, to: 1.2, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        
        for (_, backgroundNode) in self.backgroundNodes {
            backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false)
        }
        
        for (identifier, itemNode) in self.itemNodes {
            if let (transitionView, completion) = self.getTransitionView(identifier) {
                itemNode.animateTo(transitionView, completion: completion)
            } else {
                itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false)
            }
        }
        
        self.messageNodes?.first?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
        self.messageNodes?.first?.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -30.0), duration: 0.4, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
        
        self.messageNodes?.last?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
        self.messageNodes?.last?.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: 30.0), duration: 0.4, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.interaction?.dismissInput()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateAbsoluteRects()
    }
    
    func scrollToTop(animated: Bool) {
        self.scrollNode.view.setContentOffset(CGPoint(), animated: animated)
    }
    
    func updateAbsoluteRects() {
        guard let messageNodes = self.messageNodes, let (size, _, _, _, _, _, _) = self.validLayout else {
            return
        }
        
        for itemNode in messageNodes {
            var absoluteRect = itemNode.frame
            if let supernode = self.supernode {
                absoluteRect = supernode.convert(itemNode.bounds, from: itemNode)
            }
            absoluteRect.origin.y = size.height - absoluteRect.origin.y - absoluteRect.size.height
            itemNode.updateAbsoluteRect(absoluteRect, within: self.bounds.size)
        }
        
        for (_, itemNode) in self.backgroundNodes {
            var absoluteRect = itemNode.frame
            if let supernode = self.supernode {
                absoluteRect = supernode.convert(itemNode.bounds, from: itemNode)
            }
            absoluteRect.origin.y = size.height - absoluteRect.origin.y - absoluteRect.size.height
            itemNode.updateAbsoluteRect(absoluteRect, within: self.bounds.size)
        }
    }
    
    private func beginReordering(itemNode: MediaPickerSelectedItemNode) {
        self.isReordering = true
        
        if let reorderNode = self.reorderNode {
            reorderNode.removeFromSupernode()
        }
        
        let reorderNode = ReorderingItemNode(itemNode: itemNode, initialLocation: itemNode.frame.origin)
        self.reorderNode = reorderNode
        self.scrollNode.addSubnode(reorderNode)
        
        itemNode.isHidden = true
        
        if self.reorderFeedback == nil {
            self.reorderFeedback = HapticFeedback()
        }
        self.reorderFeedback?.impact()
    }
    
    private func endReordering(point: CGPoint?) {
        if let reorderNode = self.reorderNode {
            self.reorderNode = nil
        
            if let itemNode = reorderNode.itemNode, let point = point {
                var targetNode: MediaPickerSelectedItemNode?
                for (_, node) in self.itemNodes {
                    if node.frame.contains(point) {
                        targetNode = node
                        break
                    }
                }
                
                if let targetNode = targetNode, let targetIndex = self.interaction?.selectionState?.index(of: targetNode.asset) {
                    self.interaction?.selectionState?.move(itemNode.asset, to: targetIndex)
                }
                reorderNode.animateCompletion(completion: { [weak reorderNode] in
                    reorderNode?.removeFromSupernode()
                })
                self.reorderFeedback?.tap()
            } else {
                reorderNode.removeFromSupernode()
                reorderNode.itemNode?.isHidden = false
            }
        }
        
        self.isReordering = false
    }
    
    private func updateReordering(offset: CGPoint) {
        if let reorderNode = self.reorderNode {
            reorderNode.updateOffset(offset: offset)
        }
    }
    
    private var messageNodes: [ListViewItemNode]?
    private func updateItems(transition: ContainedViewLayoutTransition) {
        guard let (size, insets, items, grouped, theme, wallpaper, bubbleCorners) = self.validLayout else {
            return
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        var itemSizes: [CGSize] = []
        let sideInset: CGFloat = 34.0
        let boundingWidth = min(320.0, size.width - insets.left - insets.right - sideInset * 2.0)
        
        var validIds: [String] = []
        for item in items {
            guard let asset = item as? TGMediaAsset, let identifier = asset.uniqueIdentifier else {
                continue
            }
            
            validIds.append(identifier)
            let itemNode: MediaPickerSelectedItemNode
            if let current = self.itemNodes[identifier] {
                itemNode = current
            } else {
                itemNode = MediaPickerSelectedItemNode(asset: asset, interaction: self.interaction)
                self.itemNodes[identifier] = itemNode
                self.scrollNode.addSubnode(itemNode)
                
                itemNode.setup(size: CGSize(width: boundingWidth, height: boundingWidth))
            }
            itemNode.update(theme: theme)
            itemNode.updateSelectionState()
            if !self.isReordering {
                itemNode.updateHiddenMedia()
            }
            
            if let adjustments = self.interaction?.editingState.adjustments(for: asset), adjustments.cropApplied(forAvatar: false) {
                itemSizes.append(adjustments.cropRect.size)
            } else {
                itemSizes.append(asset.dimensions)
            }
        }
        
        if !self.didSetReady {
            self.didSetReady = true
            
            var signals: [Signal<Bool, NoError>] = []
            for (_, itemNode) in self.itemNodes {
                signals.append(itemNode.ready)
            }
            self.ready.set(combineLatest(queue: Queue.mainQueue(), signals)
            |> map { _ in
                return true
            })
        }
                
        let boundingSize = CGSize(width: boundingWidth, height: boundingWidth)
        var groupLayouts: [([(TGMediaSelectableItem, CGRect, MosaicItemPosition)], CGSize)] = []
        if grouped && items.count > 1 {
            let groupSize = 10
            for i in stride(from: 0, to: itemSizes.count, by: groupSize) {
                let sizes = itemSizes[i ..< min(i + groupSize, itemSizes.count)]
                let items = items[i ..< min(i + groupSize, items.count)]
                
                if items.count > 1 {
                    let (mosaicLayout, size) = chatMessageBubbleMosaicLayout(maxSize: boundingSize, itemSizes: Array(sizes), spacing: 1.0, fillWidth: true)
                    let layout = zip(items, mosaicLayout).map { ($0, $1.0, $1.1) }
                    groupLayouts.append((layout, size))
                } else if let item = items.first, var itemSize = sizes.first {
                    if itemSize.width > itemSize.height {
                        itemSize = itemSize.aspectFitted(boundingSize)
                    } else {
                        itemSize = boundingSize
                    }
                    let itemRect = CGRect(origin: CGPoint(), size: itemSize)
                    let position: MosaicItemPosition = [.top, .bottom, .left, .right]
                    groupLayouts.append(([(item, itemRect, position)], itemRect.size))
                }
            }
        } else {
            for i in 0 ..< itemSizes.count {
                let item = items[i]
                var itemSize = itemSizes[i]
                if itemSize.width > itemSize.height {
                    itemSize = itemSize.aspectFitted(boundingSize)
                } else {
                    itemSize = boundingSize
                }
                let itemRect = CGRect(origin: CGPoint(), size: itemSize)
                let position: MosaicItemPosition = [.top, .bottom, .left, .right]
                groupLayouts.append(([(item, itemRect, position)], itemRect.size))
            }
        }
        
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
        var peers = SimpleDictionary<PeerId, Peer>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let previewText = groupLayouts.count > 1 ? presentationData.strings.Attachment_MessagesPreview : presentationData.strings.Attachment_MessagePreview
        
        let previewMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [TelegramMediaAction(action: .customText(text: previewText, entities: []))], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        let previewItem = self.context.sharedContext.makeChatMessagePreviewItem(context: context, messages: [previewMessage], theme: theme, strings: presentationData.strings, wallpaper: wallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: bubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.wallpaperBackgroundNode, availableReactions: nil, isCentered: true)
        
        let dragMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [TelegramMediaAction(action: .customText(text: presentationData.strings.Attachment_DragToReorder, entities: []))], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        let dragItem = self.context.sharedContext.makeChatMessagePreviewItem(context: context, messages: [dragMessage], theme: theme, strings: presentationData.strings, wallpaper: wallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: bubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.wallpaperBackgroundNode, availableReactions: nil, isCentered: true)
        
        let headerItems: [ListViewItem] = [previewItem, dragItem]
        
        let params = ListViewItemLayoutParams(width: size.width, leftInset: insets.left, rightInset: insets.right, availableHeight: size.height)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< headerItems.count {
                let itemNode = messageNodes[i]
                headerItems[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: nil, nextItem: nil, animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: size.width, height: layout.size.height))
                    
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = nodeFrame
                    itemNode.isUserInteractionEnabled = false
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< headerItems.count {
                var itemNode: ListViewItemNode?
                headerItems[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
                itemNode!.isUserInteractionEnabled = false
                messageNodes.append(itemNode!)
                self.scrollNode.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        let spacing: CGFloat = 8.0
        var contentHeight: CGFloat = 60.0
        
        if let previewNode = self.messageNodes?.first {
            transition.updateFrame(node: previewNode, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top + 28.0), size: previewNode.frame.size))
            
            var previewNodeFrame = previewNode.frame
            previewNodeFrame.origin.y = size.height - previewNodeFrame.origin.y - previewNodeFrame.size.height
            
            previewNode.updateFrame(previewNodeFrame, within: size, updateFrame: false)
        }
        
        let graphics = PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: wallpaper, bubbleCorners: bubbleCorners)
        
        var groupIndex = 0
        for (items, groupSize) in groupLayouts {
            let groupRect = CGRect(origin: CGPoint(x: insets.left + floorToScreenPixels((size.width - insets.left - insets.right - groupSize.width) / 2.0), y: insets.top + contentHeight), size: groupSize)
            
            let groupBackgroundNode: MessageBackgroundNode
            if let current = self.backgroundNodes[groupIndex] {
                groupBackgroundNode = current
            } else {
                groupBackgroundNode = MessageBackgroundNode()
                groupBackgroundNode.displaysAsynchronously = false
                self.backgroundNodes[groupIndex] = groupBackgroundNode
                self.scrollNode.insertSubnode(groupBackgroundNode, at: 0)
            }
            
            var itemTransition = transition
            if groupBackgroundNode.frame.width.isZero {
                itemTransition = .immediate
            }

            itemTransition.updateFrame(node: groupBackgroundNode, frame: groupRect.insetBy(dx: -5.0, dy: -2.0).offsetBy(dx: 3.0, dy: 0.0))
            groupBackgroundNode.update(size: groupBackgroundNode.frame.size, theme: theme, wallpaper: wallpaper, graphics: graphics, wallpaperBackgroundNode: self.wallpaperBackgroundNode, transition: itemTransition)
            
            for (item, itemRect, itemPosition) in items {
                if let identifier = item.uniqueIdentifier, let itemNode = self.itemNodes[identifier] {
                    var corners: CACornerMask = []
                    if itemPosition.contains(.top) && itemPosition.contains(.left) {
                        corners.insert(.layerMinXMinYCorner)
                    }
                    if itemPosition.contains(.top) && itemPosition.contains(.right) {
                        corners.insert(.layerMaxXMinYCorner)
                    }
                    if itemPosition.contains(.bottom) && itemPosition.contains(.left) {
                        corners.insert(.layerMinXMaxYCorner)
                    }
                    if itemPosition.contains(.bottom) && itemPosition.contains(.right) {
                        corners.insert(.layerMaxXMaxYCorner)
                    }
                    itemNode.corners = corners
                    itemNode.radius = bubbleCorners.mainRadius
                    
                    var itemTransition = itemTransition
                    if itemNode.frame.width.isZero {
                        itemTransition = .immediate
                    }
                    
                    itemNode.updateLayout(size: itemRect.size, transition: itemTransition)
                    itemTransition.updateFrame(node: itemNode, frame: itemRect.offsetBy(dx: groupRect.minX, dy: groupRect.minY))
                    
                    if case .immediate = itemTransition, case .animated = transition {
                        transition.animateTransformScale(node: itemNode, from: 0.01)
                        itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
            
            contentHeight += groupSize.height + spacing
            groupIndex += 1
        }
        
        if let dragNode = self.messageNodes?.last {
            transition.updateAlpha(node: dragNode, alpha: items.count > 1 ? 1.0 : 0.0)
            transition.updateFrame(node: dragNode, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top + contentHeight + 1.0), size: dragNode.frame.size))
            
            var dragNodeFrame = dragNode.frame
            dragNodeFrame.origin.y = size.height - dragNodeFrame.origin.y - dragNodeFrame.size.height
            
            dragNode.updateFrame(dragNodeFrame, within: size, updateFrame: false)
            contentHeight += 60.0
        }
        
        contentHeight += insets.top
        contentHeight += insets.bottom
        
        var removeIds: [String] = []
        for id in self.itemNodes.keys {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                if transition.isAnimated {
                    itemNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                    itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak itemNode] _ in
                        itemNode?.removeFromSupernode()
                    })
                } else {
                    itemNode.removeFromSupernode()
                }
            }
        }
        
        for id in self.backgroundNodes.keys {
            if id > groupLayouts.count - 1 {
                if let itemNode = self.backgroundNodes.removeValue(forKey: id) {
                    if transition.isAnimated {
                        itemNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                        itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak itemNode] _ in
                            itemNode?.removeFromSupernode()
                        })
                    } else {
                        itemNode.removeFromSupernode()
                    }
                }
            }
        }
        
        if case let .animated(duration, curve) = transition, self.scrollNode.view.contentSize.height > contentHeight {
            let maxContentOffset = max(0.0, contentHeight - self.scrollNode.frame.height)
            if self.scrollNode.view.contentOffset.y > maxContentOffset {
                let updatedBounds = CGRect(origin: CGPoint(x: 0.0, y: maxContentOffset), size: self.scrollNode.bounds.size)
                let previousBounds = self.scrollNode.bounds
                self.scrollNode.bounds = updatedBounds
                self.scrollNode.layer.animateBounds(from: previousBounds, to: updatedBounds, duration: duration, timingFunction: curve.timingFunction)
            }
        }
        
        self.updateAbsoluteRects()
        
        self.scrollNode.view.contentSize = CGSize(width: size.width, height: contentHeight)
    }
    
    func updateSelectionState() {
        for (_, itemNode) in self.itemNodes {
            itemNode.updateSelectionState()
        }
    }
    
    func updateHiddenMedia() {
        for (_, itemNode) in self.itemNodes {
            itemNode.updateHiddenMedia()
        }
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, items: [TGMediaSelectableItem], grouped: Bool, theme: PresentationTheme, wallpaper: TelegramWallpaper, bubbleCorners: PresentationChatBubbleCorners, transition: ContainedViewLayoutTransition) {
        let previous = self.validLayout
        self.validLayout = (size, insets, items, grouped, theme, wallpaper, bubbleCorners)
        
        if previous?.theme !== theme || previous?.wallpaper != wallpaper || previous?.bubbleCorners != bubbleCorners {
            self.graphics = PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: wallpaper, bubbleCorners: bubbleCorners)
        }
        
        var itemsTransition = transition
        if previous?.grouped != grouped {
            if let snapshotView = self.view.snapshotView(afterScreenUpdates: false) {
                self.view.addSubview(snapshotView)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
            }
            itemsTransition = .immediate
        }
        
        let inset: CGFloat = insets.left == 70 ? insets.left : 0.0
        self.wallpaperBackgroundNode.update(wallpaper: wallpaper)
        self.wallpaperBackgroundNode.updateBubbleTheme(bubbleTheme: theme, bubbleCorners: bubbleCorners)
        transition.updateFrame(node: self.wallpaperBackgroundNode, frame: CGRect(origin: CGPoint(x: inset, y: 0.0), size: CGSize(width: size.width - inset * 2.0, height: size.height)))
        self.wallpaperBackgroundNode.updateLayout(size: CGSize(width: size.width - inset * 2.0, height: size.height), transition: transition)
        
        self.updateItems(transition: itemsTransition)
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        transition.updateFrame(node: self.scrollNode, frame: bounds)
    }
    
    func transitionView(for identifier: String, hideSource: Bool) -> UIView? {
        if hideSource {
            for (_, node) in self.backgroundNodes {
                node.alpha = 0.01
            }
        }
        for (_, itemNode) in self.itemNodes {
            if itemNode.asset.uniqueIdentifier == identifier {
                if hideSource {
                    itemNode.alpha = 0.01
                }
                return itemNode.transitionView()
            }
        }
        return nil
    }
}

private class ReorderingGestureRecognizer: UIGestureRecognizer {
    private let shouldBegin: (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, itemNode: MediaPickerSelectedItemNode?)
    private let willBegin: (CGPoint) -> Void
    private let began: (MediaPickerSelectedItemNode) -> Void
    private let ended: (CGPoint?) -> Void
    private let moved: (CGPoint) -> Void
    
    private var initialLocation: CGPoint?
    private var longPressTimer: SwiftSignalKit.Timer?
    
    private var itemNode: MediaPickerSelectedItemNode?
    
    public init(shouldBegin: @escaping (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, itemNode: MediaPickerSelectedItemNode?), willBegin: @escaping (CGPoint) -> Void, began: @escaping (MediaPickerSelectedItemNode) -> Void, ended: @escaping (CGPoint?) -> Void, moved: @escaping (CGPoint) -> Void) {
        self.shouldBegin = shouldBegin
        self.willBegin = willBegin
        self.began = began
        self.ended = ended
        self.moved = moved
        
        super.init(target: nil, action: nil)
    }
    
    deinit {
        self.longPressTimer?.invalidate()
    }
    
    private func startLongPressTimer() {
        self.longPressTimer?.invalidate()
        let longPressTimer = SwiftSignalKit.Timer(timeout: 0.3, repeat: false, completion: { [weak self] in
            self?.longPressTimerFired()
        }, queue: Queue.mainQueue())
        self.longPressTimer = longPressTimer
        longPressTimer.start()
    }
    
    private func stopLongPressTimer() {
        self.itemNode = nil
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
    }
    
    override public func reset() {
        super.reset()
        
        self.itemNode = nil
        self.stopLongPressTimer()
        self.initialLocation = nil
    }
    
 
    private func longPressTimerFired() {
        guard let _ = self.initialLocation else {
            return
        }
        
        self.state = .began
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
        if let itemNode = self.itemNode {
            self.began(itemNode)
        }
    }
    
    private var currentItemNode: ASDisplayNode?
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.numberOfTouches > 1 {
            self.state = .failed
            self.ended(nil)
            return
        }
        
        if self.state == .possible {
            if let location = touches.first?.location(in: self.view) {
                let (allowed, requiresLongPress, itemNode) = self.shouldBegin(location)
                if allowed {
                    if let itemNode = itemNode {
                        itemNode.layer.animateScale(from: 1.0, to: 0.98, duration: 0.2, delay: 0.1)
                    }
                    self.itemNode = itemNode
                    self.initialLocation = location
                    if requiresLongPress {
                        self.startLongPressTimer()
                    } else {
                        self.state = .began
                        if let itemNode = self.itemNode {
                            self.began(itemNode)
                        }
                    }
                } else {
                    self.state = .failed
                }
            } else {
                self.state = .failed
            }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.initialLocation = nil
        
        if self.longPressTimer != nil {
            self.stopLongPressTimer()
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            if let location = touches.first?.location(in: self.view) {
                self.ended(location)
            } else {
                self.ended(nil)
            }
            self.state = .failed
        }
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.initialLocation = nil
        
        if self.longPressTimer != nil {
            self.stopLongPressTimer()
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.ended(nil)
            self.state = .failed
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if (self.state == .began || self.state == .changed), let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) {
            self.state = .changed
            self.moved(CGPoint(x: location.x - initialLocation.x, y: location.y - initialLocation.y))
        } else if let touch = touches.first, let initialTapLocation = self.initialLocation, self.longPressTimer != nil {
            let touchLocation = touch.location(in: self.view)
            let dX = touchLocation.x - initialTapLocation.x
            let dY = touchLocation.y - initialTapLocation.y
            
            if dX * dX + dY * dY > 3.0 * 3.0 {
                self.itemNode?.layer.removeAllAnimations()
                
                self.stopLongPressTimer()
                self.initialLocation = nil
                self.state = .failed
            }
        }
    }
}


private func generateShadowImage(corners: CACornerMask, radius: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: 120.0, height: 120), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
//        context.saveGState()
        context.setShadow(offset: CGSize(), blur: 28.0, color: UIColor(white: 0.0, alpha: 0.4).cgColor)

        var rectCorners: UIRectCorner = []
        if corners.contains(.layerMinXMinYCorner) {
            rectCorners.insert(.topLeft)
        }
        if corners.contains(.layerMaxXMinYCorner) {
            rectCorners.insert(.topRight)
        }
        if corners.contains(.layerMinXMaxYCorner) {
            rectCorners.insert(.bottomLeft)
        }
        if corners.contains(.layerMaxXMaxYCorner) {
            rectCorners.insert(.bottomRight)
        }
        
        let path = UIBezierPath(roundedRect: CGRect(x: 30.0, y: 30.0, width: 60.0, height: 60.0), byRoundingCorners: rectCorners, cornerRadii: CGSize(width: radius, height: radius)).cgPath
        context.addPath(path)
        context.fillPath()
//        context.restoreGState()
        
//        context.setBlendMode(.clear)
//        context.addPath(path)
//        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 60, topCapHeight: 60)
}

private final class CopyView: UIView {
    let shadow: UIImageView
    var snapshotView: UIView?
    
    init(frame: CGRect, corners: CACornerMask, radius: CGFloat) {
        self.shadow = UIImageView()
        self.shadow.contentMode = .scaleToFill
        
        super.init(frame: frame)
    
        self.shadow.image = generateShadowImage(corners: corners, radius: radius)
    
        self.addSubview(self.shadow)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ReorderingItemNode: ASDisplayNode {
    weak var itemNode: MediaPickerSelectedItemNode?
    
    var currentState: (Int, Int)?
    
    private let copyView: CopyView
    private let initialLocation: CGPoint
    
    init(itemNode: MediaPickerSelectedItemNode, initialLocation: CGPoint) {
        self.itemNode = itemNode
        self.copyView = CopyView(frame: CGRect(), corners: itemNode.corners, radius: itemNode.radius)
        let snapshotView = itemNode.view.snapshotView(afterScreenUpdates: false)
        self.initialLocation = initialLocation
        
        super.init()
        
        if let snapshotView = snapshotView {
            snapshotView.frame = CGRect(origin: CGPoint(), size: itemNode.bounds.size)
            snapshotView.bounds.origin = itemNode.bounds.origin
            self.copyView.addSubview(snapshotView)
            self.copyView.snapshotView = snapshotView
        }
        self.view.addSubview(self.copyView)
        self.copyView.frame = CGRect(origin: CGPoint(x: initialLocation.x, y: initialLocation.y), size: itemNode.bounds.size)
        self.copyView.shadow.frame = CGRect(origin: CGPoint(x: -30.0, y: -30.0), size: CGSize(width: itemNode.bounds.size.width + 60.0, height: itemNode.bounds.size.height + 60.0))
        self.copyView.shadow.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        
        self.copyView.snapshotView?.layer.animateScale(from: 1.0, to: 1.05, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.copyView.shadow.layer.animateScale(from: 1.0, to: 1.05, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
    }
    
    func updateOffset(offset: CGPoint) {
        self.copyView.frame = CGRect(origin: CGPoint(x: initialLocation.x + offset.x, y: initialLocation.y + offset.y), size: copyView.bounds.size)
    }
    
    func currentOffset() -> CGFloat? {
        return self.copyView.center.y
    }
    
    func animateCompletion(completion: @escaping () -> Void) {
        if let itemNode = self.itemNode {
            itemNode.view.superview?.bringSubviewToFront(itemNode.view)
                        
            itemNode.layer.animateScale(from: 1.05, to: 1.0, duration: 0.25, removeOnCompletion: false)
            
            let sourceFrame = self.view.convert(self.copyView.frame, to: itemNode.supernode?.view)
            let targetFrame = itemNode.frame
            itemNode.updateLayout(size: sourceFrame.size, transition: .immediate)
            itemNode.layer.animateFrame(from: sourceFrame, to: targetFrame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                completion()
            })
            itemNode.updateLayout(size: targetFrame.size, transition: .animated(duration: 0.3, curve: .spring))
            
            itemNode.isHidden = false
            self.copyView.isHidden = true
        } else {
            completion()
        }
    }
}
