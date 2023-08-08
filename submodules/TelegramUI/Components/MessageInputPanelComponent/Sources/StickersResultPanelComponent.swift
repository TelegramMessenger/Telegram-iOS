import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PeerListItemComponent
import EmojiTextAttachmentView
import TextFormat
import ContextUI
import StickerPeekUI
import UndoUI

final class StickersResultPanelComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let files: [TelegramMediaFile]
    let action: (TelegramMediaFile) -> Void
    let present: (ViewController) -> Void
    let presentInGlobalOverlay: (ViewController) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        files: [TelegramMediaFile],
        action: @escaping (TelegramMediaFile) -> Void,
        present: @escaping (ViewController) -> Void,
        presentInGlobalOverlay: @escaping (ViewController) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.files = files
        self.action = action
        self.present = present
        self.presentInGlobalOverlay = presentInGlobalOverlay
    }
    
    static func ==(lhs: StickersResultPanelComponent, rhs: StickersResultPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.files != rhs.files {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var bottomInset: CGFloat
        var topInset: CGFloat
        var sideInset: CGFloat
        var itemSize: CGSize
        var itemSpacing: CGFloat
        var itemsPerRow: Int
        var itemCount: Int
        
        var contentSize: CGSize
        
        init(containerSize: CGSize, bottomInset: CGFloat, topInset: CGFloat, sideInset: CGFloat, itemSize: CGSize, itemSpacing: CGFloat, itemsPerRow: Int, itemCount: Int) {
            self.containerSize = containerSize
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.sideInset = sideInset
            self.itemSize = itemSize
            self.itemSpacing = itemSpacing
            self.itemsPerRow = itemsPerRow
            self.itemCount = itemCount
            
            let rowsCount = ceil(CGFloat(itemCount) / CGFloat(itemsPerRow))
            self.contentSize = CGSize(width: containerSize.width, height: topInset + rowsCount * (itemSize.height + itemSpacing) - itemSpacing + bottomInset)
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: 0.0, dy: -self.topInset)
            var minVisibleRow = Int(floor((offsetRect.minY) / (self.itemSize.height + self.itemSpacing)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxY) / (self.itemSize.height + self.itemSpacing)))
            
            let minVisibleIndex = minVisibleRow * self.itemsPerRow
            let maxVisibleIndex = maxVisibleRow * self.itemsPerRow + self.itemsPerRow
            
            if maxVisibleIndex >= minVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
        
        func itemFrame(for index: Int) -> CGRect {
            let rowIndex = Int(floor(CGFloat(index) / CGFloat(self.itemsPerRow)))
            let columnIndex = index % self.itemsPerRow
            
            return CGRect(origin: CGPoint(x: self.sideInset + CGFloat(columnIndex) * (self.itemSize.width + self.itemSpacing), y: self.topInset + CGFloat(rowIndex) * (self.itemSize.height + self.itemSpacing)), size: self.itemSize)
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private let backgroundView: BlurredBackgroundView
        private let containerView: UIView
        private let scrollView: UIScrollView
        
        private var itemLayout: ItemLayout?
        
        private var visibleLayers: [EngineMedia.Id: InlineStickerItemLayer] = [:]
        private var fadingMaskLayer: FadingMaskLayer?
        
        private var ignoreScrolling = false
        
        private var component: StickersResultPanelComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.backgroundView.isUserInteractionEnabled = false
            
            self.containerView = UIView()
            
            self.scrollView = ScrollView()
            self.scrollView.canCancelContentTouches = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.indicatorStyle = .white
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.scrollView.delegate = self
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.scrollView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
            let peekRecognizer = PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
                if let self, let component = self.component {
                    let presentationData = component.strings
                    
                    let convertedPoint = self.scrollView.convert(point, from: self)
                    guard self.scrollView.bounds.contains(convertedPoint) else {
                        return nil
                    }
                    
                    var selectedLayer: InlineStickerItemLayer?
                    for (_, layer) in self.visibleLayers {
                        if layer.frame.contains(convertedPoint) {
                            selectedLayer = layer
                            break
                        }
                    }

                    if let selectedLayer, let file = selectedLayer.file {
                        return component.context.engine.stickers.isStickerSaved(id: file.fileId)
                        |> deliverOnMainQueue
                        |> map { [weak self] isStarred -> (UIView, CGRect, PeekControllerContent)? in
                            if let self, let component = self.component {
                                let menuItems: [ContextMenuItem] = []
                                let _ = menuItems
                                let _ = presentationData
                                //                                if strongSelf.peerId != strongSelf.context.account.peerId && strongSelf.peerId?.namespace != Namespaces.Peer.SecretChat  {
                                //                                    menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                //                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                                //                                    }, action: { _, f in
                                //                                        if let strongSelf = self, let peekController = strongSelf.peekController {
                                //                                            if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                //                                                let _ = controllerInteraction.sendSticker(.standalone(media: item.file), true, false, nil, true, animationNode.view, animationNode.bounds, nil, [])
                                //                                            } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                //                                                let _ = controllerInteraction.sendSticker(.standalone(media: item.file), true, false, nil, true, imageNode.view, imageNode.bounds, nil, [])
                                //                                            }
                                //                                        }
                                //                                        f(.default)
                                //                                    })))
                                //                                }
                                //
                                //                                menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                                //                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                                //                                }, action: { _, f in
                                //                                    if let strongSelf = self, let peekController = strongSelf.peekController {
                                //                                        if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                //                                            let _ = controllerInteraction.sendSticker(.standalone(media: item.file), false, true, nil, true, animationNode.view, animationNode.bounds, nil, [])
                                //                                        } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                //                                            let _ = controllerInteraction.sendSticker(.standalone(media: item.file), false, true, nil, true, imageNode.view, imageNode.bounds, nil, [])
                                //                                        }
                                //                                    }
                                //                                    f(.default)
                                //                                })))

//                                menuItems.append(
//                                    .action(ContextMenuActionItem(text: isStarred ? presentationData.strings.Stickers_RemoveFromFavorites : presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
//                                        f(.default)
//
//                                        if let self, let component = self.component {
//                                            let _ = (component.context.engine.stickers.toggleStickerSaved(file: file, saved: !isStarred)
//                                            |> deliverOnMainQueue).start(next: { [weak self] result in
//                                                guard let self, let component = self.component else {
//                                                    return
//                                                }
//                                                switch result {
//                                                case .generic:
//                                                    let controller = UndoOverlayController(presentationData: presentationData, content: .sticker(context: component.context, file: file, loop: true, title: nil, text: !isStarred ? presentationData.strings.Conversation_StickerAddedToFavorites : presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false })
//                                                    component.presentInGlobalOverlay(controller)
//                                                case let .limitExceeded(limit, premiumLimit):
//                                                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
//                                                    let text: String
//                                                    if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
//                                                        text = presentationData.strings.Premium_MaxFavedStickersFinalText
//                                                    } else {
//                                                        text = presentationData.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
//                                                    }
//
//                                                    let controller = UndoOverlayController(presentationData: presentationData, content: .sticker(context: component.context, file: file, loop: true, title: presentationData.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil, customAction: nil), elevatedLayout: false, action: { [weak self] action in
//                                                        if let self, let component = self.component {
//                                                            if case .info = action {
//                                                                let controller = component.context.sharedContext.makePremiumIntroController(context: component.context, source: .savedStickers)
//                                                                //                                                                strongSelf.getControllerInteraction?()?.navigationController()?.pushViewController(controller)
//                                                                return true
//                                                            }
//                                                        }
//                                                        return false
//                                                    })
//                                                    component.presentInGlobalOverlay(controller)
//                                                }
//                                            })
//                                        }
//                                    }))
//                                )
//
//                                menuItems.append(
//                                    .action(ContextMenuActionItem(text: presentationData.strings.StickerPack_ViewPack, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
//                                        f(.default)
//
//                                        if let self, let component = self.component {
//                                        loop: for attribute in file.attributes {
//                                            switch attribute {
//                                            case let .Sticker(_, packReference, _):
//                                                if let packReference = packReference {
//                                                    let controller = component.context.sharedContext.makeStickerPackScreen(context: component.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: nil, sendSticker: { [weak self] file, sourceNode, sourceRect in
//                                                        if let self, let component = self.component {
//                                                            component.action(file)
//                                                            return true
//                                                        } else {
//                                                            return false
//                                                        }
//                                                    })
//                                                    component.present(controller)
//                                                }
//                                                break loop
//                                            default:
//                                                break
//                                            }
//                                        }
//                                        }
//                                    }))
//                                )
                                return (self, self.scrollView.convert(selectedLayer.frame, to: self), StickerPreviewPeekContent(context: component.context, theme: component.theme, strings: component.strings, item: .pack(file), menu: menuItems, openPremiumIntro: { [weak self] in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    let controller = component.context.sharedContext.makePremiumIntroController(context: component.context, source: .stickers, forceDark: false, dismissed: nil)
                                    component.present(controller)
                                }))
                            } else {
                                return nil
                            }
                        }
                    }
                }
                return nil
            }, present: { [weak self] content, sourceView, sourceRect in
                if let self, let component = self.component {
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: component.theme)
                    let controller = PeekController(presentationData: presentationData, content: content, sourceView: {
                        return (sourceView, sourceRect)
                    })
                    component.presentInGlobalOverlay(controller)
                    return controller
                }
                return nil
            }, updateContent: { [weak self] content in
                if let self {
                    var item: TelegramMediaFile?
                    if let content = content as? StickerPreviewPeekContent, case let .pack(contentItem) = content.item {
                        item = contentItem
                    }
                    let _ = item
                    let _ = self
                    //strongSelf.updatePreviewingItem(file: item, animated: true)
                }
            })
            self.addGestureRecognizer(peekRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
                        if itemLayer.frame.contains(location) {
                            closestFile = (file, 0.0)
                        }
                    }
                    if let (file, _) = closestFile {
                        self.component?.action(file)
                    }
                }
            }
        }
        
        func animateIn(transition: Transition) {
            let offset = self.scrollView.contentOffset.y * -1.0 + 10.0
            Transition.immediate.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: -offset))
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: 0.0))
        }
        
        func animateOut(transition: Transition, completion: @escaping () -> Void) {
            let offset = self.scrollView.contentOffset.y * -1.0 + 10.0
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: -offset), completion: { _ in
                completion()
            })
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -200.0)
            
            var synchronousLoad = false
            if let hint = transition.userData(PeerListItemComponent.TransitionHint.self) {
                synchronousLoad = hint.synchronousLoad
            }
                        
            var visibleIds = Set<EngineMedia.Id>()
            if let range = itemLayout.visibleItems(for: visibleBounds) {
                for index in range.lowerBound ..< range.upperBound {
                    guard index < component.files.count else {
                        continue
                    }
                    
                    let itemFrame = itemLayout.itemFrame(for: index)
                                        
                    let item = component.files[index]
                    visibleIds.insert(item.fileId)
                    
                    let itemLayer: InlineStickerItemLayer
                    if let current = self.visibleLayers[item.fileId] {
                        itemLayer = current
                        itemLayer.dynamicColor = .white
                    } else {
                        itemLayer = InlineStickerItemLayer(
                            context: component.context,
                            userLocation: .other,
                            attemptSynchronousLoad: synchronousLoad,
                            emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: item.fileId.id, file: item),
                            file: item,
                            cache: component.context.animationCache,
                            renderer: component.context.animationRenderer,
                            placeholderColor: UIColor(rgb: 0xffffff).mixedWith(UIColor(rgb: 0x1c1c1d), alpha: 0.9),
                            pointSize: itemFrame.size,
                            dynamicColor: .white
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
            
            let backgroundSize = CGSize(width: self.scrollView.frame.width, height: self.scrollView.frame.height + 20.0)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: max(0.0, self.scrollView.contentOffset.y * -1.0)), size: backgroundSize))
            self.backgroundView.update(size: backgroundSize, cornerRadius: 11.0, transition: transition.containedViewLayoutTransition)
        }
        
        func update(component: StickersResultPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            //let itemUpdated = self.component?.results != component.results
            
            self.component = component
            self.state = state
            
            let minimizedHeight = min(availableSize.height, 500.0)
                        
            self.backgroundView.updateColor(color: UIColor(white: 0.0, alpha: 0.7), transition: transition.containedViewLayoutTransition)
                        
            let itemsPerRow = min(8, max(5, Int(availableSize.width / 80)))
            let sideInset: CGFloat = 2.0
            let itemSpacing: CGFloat = 2.0
            let itemSize = floor((availableSize.width - sideInset * 2.0 - itemSpacing * (CGFloat(itemsPerRow) - 1.0)) / CGFloat(itemsPerRow))
            
            let itemLayout = ItemLayout(
                containerSize: CGSize(width: availableSize.width, height: minimizedHeight),
                bottomInset: 40.0,
                topInset: 9.0,
                sideInset: sideInset,
                itemSize: CGSize(width: itemSize, height: itemSize),
                itemSpacing: itemSpacing,
                itemsPerRow: itemsPerRow,
                itemCount: component.files.count
            )
            self.itemLayout = itemLayout
            
            let scrollContentSize = itemLayout.contentSize
            
            self.ignoreScrolling = true
            
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: minimizedHeight)))

            let visibleTopContentHeight = min(scrollContentSize.height, itemSize * 3.0 + 19.0)
            let topInset = availableSize.height - visibleTopContentHeight
            
            let scrollContentInsets = UIEdgeInsets(top: topInset, left: 0.0, bottom: 19.0, right: 0.0)
            let scrollIndicatorInsets = UIEdgeInsets(top: topInset + 17.0, left: 0.0, bottom: 19.0, right: 0.0)
            if self.scrollView.contentInset != scrollContentInsets {
                self.scrollView.contentInset = scrollContentInsets
            }
            if self.scrollView.scrollIndicatorInsets != scrollIndicatorInsets {
                self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets
            }
            if self.scrollView.contentSize != scrollContentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            
            let maskLayer: FadingMaskLayer
            if let current = self.fadingMaskLayer {
                maskLayer = current
            } else {
                maskLayer = FadingMaskLayer()
                self.fadingMaskLayer = maskLayer
            }
            if self.containerView.layer.mask == nil {
                self.containerView.layer.mask = maskLayer
            }
            maskLayer.frame = CGRect(origin: .zero, size: self.scrollView.frame.size)
            
            self.containerView.frame = CGRect(origin: .zero, size: availableSize)
            
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class FadingMaskLayer: SimpleLayer {
    let gradientLayer = SimpleLayer()
    let fillLayer = SimpleLayer()
    
    override func layoutSublayers() {
        let gradientHeight: CGFloat = 110.0
        if self.gradientLayer.contents == nil {
            self.addSublayer(self.gradientLayer)
            self.addSublayer(self.fillLayer)
            
            let gradientImage = generateGradientImage(size: CGSize(width: 1.0, height: gradientHeight), colors: [UIColor.white, UIColor.white, UIColor.white.withAlphaComponent(0.0), UIColor.white.withAlphaComponent(0.0)], locations: [0.0, 0.4, 0.9, 1.0], direction: .vertical)
            self.gradientLayer.contents = gradientImage?.cgImage
            self.gradientLayer.contentsGravity = .resize
            self.fillLayer.backgroundColor = UIColor.white.cgColor
        }
        
        self.fillLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.width, height: self.bounds.height - gradientHeight))
        self.gradientLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: self.bounds.height - gradientHeight), size: CGSize(width: self.bounds.width, height: gradientHeight))
    }
}
