import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SearchBarNode
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import EntityKeyboard
import ContextUI
import GlassControls
import MultilineTextComponent
import ChatControllerInteraction
import MultiplexedVideoNode
import FeaturedStickersScreen
import StickerPeekUI
import EntityKeyboardGifContent
import BatchVideoRendering
import UndoUI

private let searchBarHeight: CGFloat = 76.0
private let searchBarTopInset: CGFloat = 16.0
private let searchBarFieldHeight: CGFloat = 44.0

private func paneSearchBarTheme(_ theme: PresentationTheme) -> SearchBarNodeTheme {
    return SearchBarNodeTheme(
        background: .clear,
        separator: .clear,
        inputFill: .clear,
        primaryText: theme.chat.inputPanel.panelControlColor,
        placeholder: theme.chat.inputPanel.inputPlaceholderColor,
        inputIcon: theme.chat.inputPanel.inputControlColor,
        inputClear: theme.chat.inputPanel.panelControlColor,
        accent: theme.chat.inputPanel.panelControlAccentColor,
        keyboard: theme.rootController.keyboardColor
    )
}

public protocol PaneSearchContentNode {
    var ready: Signal<Void, NoError> { get }
    var deactivateSearchBar: (() -> Void)? { get set }
    var updateActivity: ((Bool) -> Void)? { get set }

    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings)
    func updateText(_ text: String, languageCode: String?)
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition)

    func animateIn(additivePosition: CGFloat, transition: ContainedViewLayoutTransition)
    func animateOut(transition: ContainedViewLayoutTransition)

    func updatePreviewing(animated: Bool)
    func itemAt(point: CGPoint) -> (ASDisplayNode, Any)?
}

public final class PaneSearchContainerNode: ASDisplayNode, EntitySearchContainerNode {
    private let context: AccountContext
    private let mode: ChatMediaInputSearchMode
    public private(set) var contentNode: PaneSearchContentNode & ASDisplayNode
    private let interaction: ChatEntityKeyboardInputNode.Interaction
    private let inputNodeInteraction: ChatMediaInputNodeInteraction
    private let peekBehavior: EmojiContentPeekBehavior?

    private let backgroundNode: ASDisplayNode
    private let searchBar: SearchBarNode
    private let navigationButtons = ComponentView<Empty>()
    private let selectedPackTitle = ComponentView<Empty>()

    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var validLayout: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics)?
    private weak var animatedPlaceholder: PaneSearchBarPlaceholderNode?
    private var selectedStickerPack: StickerPaneSearchSelectedPack?

    public var onCancel: (() -> Void)?

    public var openGifContextMenu: ((MultiplexedVideoNodeFile, ASDisplayNode, CGRect, ContextGesture, Bool) -> Void)?

    public var ready: Signal<Void, NoError> {
        return self.contentNode.ready
    }

    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, interaction: ChatEntityKeyboardInputNode.Interaction, inputNodeInteraction: ChatMediaInputNodeInteraction, mode: ChatMediaInputSearchMode, batchVideoRenderingContext: BatchVideoRenderingContext?, stickerActionTitle: String? = nil, trendingGifsPromise: Promise<ChatMediaInputGifPaneTrendingState?>, cancel: @escaping () -> Void, peekBehavior: EmojiContentPeekBehavior?) {
        self.context = context
        self.mode = mode
        self.interaction = interaction
        self.inputNodeInteraction = inputNodeInteraction
        self.peekBehavior = peekBehavior
        self.theme = theme
        self.strings = strings
        switch mode {
        case .gif:
            self.contentNode = GifPaneSearchContentNode(context: context, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction, batchVideoRenderingContext: batchVideoRenderingContext ?? BatchVideoRenderingContext(context: context), trendingPromise: trendingGifsPromise)
        case .sticker, .trending:
            self.contentNode = StickerPaneSearchContentNode(context: context, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction, stickerActionTitle: stickerActionTitle)
        }
        self.backgroundNode = ASDisplayNode()

        self.searchBar = SearchBarNode(
            theme: paneSearchBarTheme(theme),
            presentationTheme: theme,
            strings: strings,
            fieldStyle: .glass,
            displayBackground: false
        )

        super.init()

        self.clipsToBounds = true

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.contentNode)
        self.addSubnode(self.searchBar)

        self.contentNode.deactivateSearchBar = { [weak self] in
            self?.searchBar.deactivate(clear: false)
        }
        self.contentNode.updateActivity = { [weak self] active in
            self?.searchBar.activity = active
        }

        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            cancel()
            self?.onCancel?()
        }
        self.searchBar.activate()

        self.searchBar.textUpdated = { [weak self] text, languageCode in
            self?.contentNode.updateText(text, languageCode: languageCode)
        }

        self.updateThemeAndStrings(theme: theme, strings: strings)

        if let contentNode = self.contentNode as? GifPaneSearchContentNode {
            contentNode.requestUpdateQuery = { [weak self] query in
                self?.updateQuery(query)
            }
            contentNode.openGifContextMenu = { [weak self] file, node, rect, gesture, isSaved in
                self?.openGifContextMenu?(file, node, rect, gesture, isSaved)
            }
        }

        if let contentNode = self.contentNode as? StickerPaneSearchContentNode {
            contentNode.selectedPackUpdated = { [weak self] pack in
                guard let self else {
                    return
                }
                self.selectedStickerPack = pack
                if pack != nil {
                    self.searchBar.deactivate(clear: false)
                }
                self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
            }
        }

        if let contentNode = self.contentNode as? StickerPaneSearchContentNode, let peekBehavior = self.peekBehavior {
            peekBehavior.setGestureRecognizerEnabled(view: self.contentNode.view, isEnabled: true, itemAtPoint: { [weak contentNode] point in
                guard let contentNode else {
                    return nil
                }
                guard let (itemNode, item) = contentNode.itemAt(point: point) else {
                    return nil
                }

                var maybeFile: TelegramMediaFile?
                if let item = item as? StickerPreviewPeekItem {
                    switch item {
                    case let .found(foundItem):
                        maybeFile = foundItem.file
                    case let .pack(fileValue):
                        maybeFile = fileValue
                    case .portal:
                        break
                    }
                }
                guard let file = maybeFile else {
                    return nil
                }

                var groupId: AnyHashable = AnyHashable("search")
                for attribute in file.attributes {
                    if case let .Sticker(_, packReference, _) = attribute {
                        if case let .id(id, _) = packReference {
                            groupId = AnyHashable(EngineItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id))
                        }
                    }
                }

                return (groupId, itemNode.layer, file)
            })
        }
    }

    public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        self.backgroundNode.backgroundColor = theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0)
        self.contentNode.updateThemeAndStrings(theme: theme, strings: strings)
        self.searchBar.updateThemeAndStrings(theme: paneSearchBarTheme(theme), presentationTheme: theme, strings: strings)

        let placeholder: String
        switch mode {
        case .gif:
            placeholder = strings.Gif_Search
        case .sticker, .trending:
            placeholder = strings.Stickers_Search
        }
        self.searchBar.placeholderString = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
    }

    public func updateQuery(_ query: String) {
        self.searchBar.text = query
    }

    public func itemAt(point: CGPoint) -> (ASDisplayNode, Any)? {
        return self.contentNode.itemAt(point: CGPoint(x: point.x, y: point.y - searchBarHeight))
    }

    private func openMore() {
        guard let selectedStickerPack = self.selectedStickerPack, let controlsView = self.navigationButtons.view as? GlassControlPanelComponent.View, let rightItemView = controlsView.rightItemView, let sourceView = rightItemView.itemView(id: AnyHashable("more")) else {
            return
        }

        let link = "https://t.me/addstickers/\(selectedStickerPack.info.shortName)"
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: self.theme)
        let strings = self.strings

        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: strings.StickerPack_Share, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, f in
            f(.default)

            guard let self else {
                return
            }
            let shareController = self.context.sharedContext.makeShareScreen(
                context: self.context,
                params: ShareControllerParams(
                    subject: .url(link),
                    externalShare: false,
                    actionCompleted: { [weak self] in
                        guard let self else {
                            return
                        }
                        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: self.theme)
                        self.interaction.presentController(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                            return false
                        }), nil)
                    }
                )
            )
            self.interaction.presentController(shareController, nil)
        })))

        items.append(.action(ContextMenuActionItem(text: strings.StickerPack_CopyLink, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, f in
            f(.default)

            UIPasteboard.general.string = link
            guard let self else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: self.theme)
            self.interaction.presentController(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                return false
            }), nil)
        })))

        if selectedStickerPack.installed {
            items.append(.separator)
            items.append(.action(ContextMenuActionItem(text: strings.StickerPack_RemoveStickerSet, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { [weak self] _, f in
                f(.default)

                guard let self else {
                    return
                }

                let info = selectedStickerPack.info
                let context = self.context
                let _ = (context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .delete)
                |> deliverOnMainQueue).start(next: { [weak self] indexAndItems in
                    guard let self, let (positionInList, items) = indexAndItems else {
                        return
                    }

                    let stickerItems = items.compactMap { $0 as? StickerPackItem }
                    if let contentNode = self.contentNode as? StickerPaneSearchContentNode {
                        contentNode.setPackInstalledState(id: info.id, installed: false)
                    }

                    var animateInAsReplacement = false
                    if let navigationController = self.interaction.getNavigationController() {
                        for controller in navigationController.overlayControllers {
                            if let controller = controller as? UndoOverlayController {
                                controller.dismissWithCommitActionAndReplacementAnimation()
                                animateInAsReplacement = true
                            }
                        }
                    }

                    let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: self.theme)
                    let undoController = UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_RemovedTitle, text: presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: stickerItems.first, context: context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { [weak self] action in
                        if case .undo = action {
                            let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: stickerItems, positionInList: positionInList).start()
                            if let contentNode = self?.contentNode as? StickerPaneSearchContentNode {
                                contentNode.setPackInstalledState(id: info.id, installed: true)
                            }
                        }
                        return true
                    })
                    if let navigationController = self.interaction.getNavigationController() {
                        navigationController.presentOverlay(controller: undoController)
                    } else {
                        self.interaction.presentController(undoController, nil)
                    }
                })
            })))
        }

        let contextController = makeContextController(
            presentationData: presentationData,
            source: .reference(StickerPaneSearchHeaderContextReferenceContentSource(sourceView: sourceView)),
            items: .single(ContextController.Items(content: .list(items))),
            gesture: nil
        )
        self.interaction.presentGlobalOverlayController(contextController, nil)
    }

    private func requestLayout(transition: ContainedViewLayoutTransition) {
        guard let (size, leftInset, rightInset, bottomInset, inputHeight, deviceMetrics) = self.validLayout else {
            return
        }
        self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: transition)
    }

    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, leftInset, rightInset, bottomInset, inputHeight, deviceMetrics)
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))

        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: searchBarTopInset), size: CGSize(width: size.width, height: searchBarFieldHeight))
        transition.updateFrame(node: self.searchBar, frame: searchBarFrame)
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
        self.searchBar.isUserInteractionEnabled = self.selectedStickerPack == nil
        transition.updateAlpha(node: self.searchBar, alpha: self.selectedStickerPack == nil ? 1.0 : 0.0)
        
        let componentTransition = ComponentTransition(transition)
        let navigationButtonsFrame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: searchBarTopInset), size: CGSize(width: max(1.0, size.width - leftInset - rightInset - 16.0 * 2.0), height: 48.0))

        let navigationButtonsSize = self.navigationButtons.update(
            transition: componentTransition,
            component: AnyComponent(GlassControlPanelComponent(
                theme: self.theme,
                leftItem: self.selectedStickerPack == nil ? nil : GlassControlPanelComponent.Item(
                    items: [
                        GlassControlGroupComponent.Item(
                            id: AnyHashable("back"),
                            content: .icon("Navigation/Back"),
                            action: { [weak self] in
                                guard let self, let contentNode = self.contentNode as? StickerPaneSearchContentNode else {
                                    return
                                }
                                contentNode.clearSelectedPack()
                            }
                        )
                    ],
                    background: .panel
                ),
                centralItem: nil,
                rightItem: self.selectedStickerPack == nil ? nil : GlassControlPanelComponent.Item(
                    items: [
                        GlassControlGroupComponent.Item(
                            id: AnyHashable("more"),
                            content: .animation("anim_morewide"),
                            action: { [weak self] in
                                self?.openMore()
                            }
                        )
                    ],
                    background: .panel
                ),
                centerAlignmentIfPossible: true,
                isDark: self.theme.overallDarkAppearance
            )),
            environment: {},
            containerSize: navigationButtonsFrame.size
        )
        if let navigationButtons = self.navigationButtons.view {
            if navigationButtons.superview == nil {
                self.view.addSubview(navigationButtons)
            }
            navigationButtons.isUserInteractionEnabled = self.selectedStickerPack != nil
            componentTransition.setFrame(view: navigationButtons, frame: CGRect(origin: navigationButtonsFrame.origin, size: navigationButtonsSize))
            //componentTransition.setAlpha(view: navigationButtons, alpha: self.selectedStickerPack != nil ? 1.0 : 0.0)
        }

        let title = self.selectedStickerPack?.info.title ?? ""
        let titleSize = self.selectedPackTitle.update(
            transition: componentTransition,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: title, font: Font.semibold(17.0), textColor: self.theme.chat.inputPanel.primaryTextColor)),
                horizontalAlignment: .center
            )),
            environment: {},
            containerSize: CGSize(width: max(1.0, size.width - leftInset - rightInset - 140.0), height: searchBarFieldHeight)
        )
        if let titleView = self.selectedPackTitle.view {
            if titleView.superview == nil {
                self.view.addSubview(titleView)
            }
            titleView.isUserInteractionEnabled = false
            let titleOrigin = CGPoint(x: leftInset + floor((size.width - leftInset - rightInset - titleSize.width) / 2.0), y: searchBarTopInset + floor((searchBarFieldHeight - titleSize.height) / 2.0))
            titleView.frame = CGRect(origin: titleOrigin, size: titleSize)
            componentTransition.setAlpha(view: titleView, alpha: self.selectedStickerPack != nil ? 1.0 : 0.0)
        }
        
        let contentFrame = CGRect(origin: CGPoint(x: leftInset, y: searchBarHeight), size: CGSize(width: size.width - leftInset - rightInset, height: size.height - searchBarHeight))
        transition.updateFrame(node: self.contentNode, frame: contentFrame)
        self.contentNode.updateLayout(size: contentFrame.size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: transition)
    }

    public func deactivate() {
        if let contentNode = self.contentNode as? StickerPaneSearchContentNode {
            contentNode.clearSelectedPack()
        }
        self.searchBar.deactivate(clear: true)
    }

    public func animateIn(from placeholder: PaneSearchBarPlaceholderNode?, anchorTop: CGPoint, anhorTopView: UIView, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        var verticalOrigin: CGFloat = anhorTopView.convert(anchorTop, to: self.view).y
        if let placeholder = placeholder {
            self.animatedPlaceholder = placeholder
            placeholder.isHidden = true

            let placeholderFrame = placeholder.view.convert(placeholder.bounds, to: self.view)
            verticalOrigin = placeholderFrame.minY - 4.0
            self.contentNode.animateIn(additivePosition: verticalOrigin, transition: transition)
        } else {
            self.contentNode.animateIn(additivePosition: 0.0, transition: transition)
        }

        let searchBarFrame = self.searchBar.frame
        let initialSearchBarFrame = CGRect(origin: CGPoint(x: searchBarFrame.minX, y: verticalOrigin), size: searchBarFrame.size)

        switch transition {
            case let .animated(duration, curve):
                self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration / 2.0)

                self.searchBar.alpha = 1.0
                self.searchBar.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, timingFunction: curve.timingFunction, completion: { _ in
                    completion()
                })
                self.searchBar.layer.animateFrame(from: initialSearchBarFrame, to: searchBarFrame, duration: duration, timingFunction: curve.timingFunction)

                if let layout = self.validLayout {
                    let initialBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: verticalOrigin), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - verticalOrigin)))
                    self.backgroundNode.layer.animateFrame(from: initialBackgroundFrame, to: self.backgroundNode.frame, duration: duration, timingFunction: curve.timingFunction)
                }
            case .immediate:
                completion()
                break
        }
    }

    public func animateOut(to placeholder: PaneSearchBarPlaceholderNode, animateOutSearchBar: Bool, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let finish: () -> Void = { [weak self] in
            placeholder.isHidden = false
            if let self, self.animatedPlaceholder === placeholder {
                self.animatedPlaceholder = nil
            }
            completion()
        }

        if case let .animated(duration, curve) = transition {
            let placeholderFrame = placeholder.view.convert(placeholder.bounds, to: self.view)
            let verticalOrigin = placeholderFrame.minY - 4.0
            let targetSearchBarFrame = CGRect(origin: CGPoint(x: self.searchBar.frame.minX, y: verticalOrigin), size: self.searchBar.frame.size)

            if let layout = self.validLayout {
                self.backgroundNode.layer.animateFrame(from: self.backgroundNode.frame, to: CGRect(origin: CGPoint(x: 0.0, y: verticalOrigin), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - verticalOrigin))), duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false)
            }

            self.searchBar.layer.animateFrame(from: self.searchBar.frame, to: targetSearchBarFrame, duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false)
            if animateOutSearchBar {
                self.searchBar.alpha = 0.0
                self.searchBar.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false, completion: { _ in
                    finish()
                })
            } else {
                self.searchBar.layer.animateAlpha(from: self.searchBar.alpha, to: self.searchBar.alpha, duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false, completion: { _ in
                    finish()
                })
            }
        } else {
            if animateOutSearchBar {
                self.searchBar.alpha = 0.0
            }
            finish()
        }

        transition.updateAlpha(node: self.backgroundNode, alpha: 0.0)
        if animateOutSearchBar {
            transition.updateAlpha(node: self.searchBar, alpha: 0.0)
        }
        let componentTransition = ComponentTransition(transition)
        if let headerView = self.navigationButtons.view {
            componentTransition.setAlpha(view: headerView, alpha: 0.0)
        }
        if let titleView = self.selectedPackTitle.view {
            componentTransition.setAlpha(view: titleView, alpha: 0.0)
        }
        self.contentNode.animateOut(transition: transition)
        self.deactivate()
    }
}

private final class StickerPaneSearchHeaderContextReferenceContentSource: ContextReferenceContentSource {
    private weak var sourceView: UIView?

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        guard let sourceView = self.sourceView else {
            return nil
        }
        return ContextControllerReferenceViewInfo(referenceView: sourceView, contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}
