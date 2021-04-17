import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import AnimatedStickerNode
import SwiftSignalKit

private final class OverlayTransitionContainerNode: ViewControllerTracingNode {
    override init() {
        super.init()
    }

    deinit {
    }

    override func didLoad() {
        super.didLoad()
    }

    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

private final class OverlayTransitionContainerController: ViewController, StandalonePresentableController {
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private var controllerNode: OverlayTransitionContainerNode {
        return self.displayNode as! OverlayTransitionContainerNode
    }

    private var wasDismissed: Bool = false

    init() {
        super.init(navigationBarPresentationData: nil)

        self.statusBar.statusBarStyle = .Ignore
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    override public func loadDisplayNode() {
        self.displayNode = OverlayTransitionContainerNode()

        self.displayNodeDidLoad()

        self._ready.set(.single(true))
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.updateLayout(layout: layout, transition: transition)
    }

    override public func viewDidAppear(_ animated: Bool) {
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        super.viewDidAppear(animated)
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.wasDismissed {
            self.wasDismissed = true
            self.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        }
    }
}

final class ChatMessageTransitionNode: ASDisplayNode {
    final class ReplyPanel {
        let titleNode: ASDisplayNode
        let textNode: ASDisplayNode
        let lineNode: ASDisplayNode
        let imageNode: ASDisplayNode
        let relativeSourceRect: CGRect

        init(titleNode: ASDisplayNode, textNode: ASDisplayNode, lineNode: ASDisplayNode, imageNode: ASDisplayNode, relativeSourceRect: CGRect) {
            self.titleNode = titleNode
            self.textNode = textNode
            self.lineNode = lineNode
            self.imageNode = imageNode
            self.relativeSourceRect = relativeSourceRect
        }
    }

    final class Sticker {
        let imageNode: TransformImageNode
        let animationNode: GenericAnimatedStickerNode?
        let placeholderNode: ASDisplayNode?
        let relativeSourceRect: CGRect

        init(imageNode: TransformImageNode, animationNode: GenericAnimatedStickerNode?, placeholderNode: ASDisplayNode?, relativeSourceRect: CGRect) {
            self.imageNode = imageNode
            self.animationNode = animationNode
            self.placeholderNode = placeholderNode
            self.relativeSourceRect = relativeSourceRect
        }
    }

    enum Source {
        final class TextInput {
            let backgroundView: UIView
            let contentView: UIView
            let sourceRect: CGRect

            init(backgroundView: UIView, contentView: UIView, sourceRect: CGRect) {
                self.backgroundView = backgroundView
                self.contentView = contentView
                self.sourceRect = sourceRect
            }
        }

        enum StickerInput {
            case inputPanel(itemNode: ChatMediaInputStickerGridItemNode)
            case mediaPanel(itemNode: HorizontalStickerGridItemNode)
            case inputPanelSearch(itemNode: StickerPaneSearchStickerItemNode)
        }

        final class AudioMicInput {
            let micButton: ChatTextInputMediaRecordingButton

            init(micButton: ChatTextInputMediaRecordingButton) {
                self.micButton = micButton
            }
        }

        case textInput(textInput: TextInput, replyPanel: ReplyAccessoryPanelNode?)
        case stickerMediaInput(input: StickerInput, replyPanel: ReplyAccessoryPanelNode?)
        case audioMicInput(AudioMicInput)
    }

    private final class AnimatingItemNode: ASDisplayNode {
        private let itemNode: ChatMessageItemView
        private let contextSourceNode: ContextExtractedContentContainingNode
        private let source: ChatMessageTransitionNode.Source

        private let scrollingContainer: ASDisplayNode
        private let containerNode: ASDisplayNode

        weak var overlayController: OverlayTransitionContainerController?

        var animationEnded: (() -> Void)?

        init(itemNode: ChatMessageItemView, contextSourceNode: ContextExtractedContentContainingNode, source: ChatMessageTransitionNode.Source) {
            self.itemNode = itemNode
            self.scrollingContainer = ASDisplayNode()
            self.containerNode = ASDisplayNode()
            self.contextSourceNode = contextSourceNode
            self.source = source

            super.init()

            self.addSubnode(self.scrollingContainer)
            self.scrollingContainer.addSubnode(self.containerNode)
        }

        deinit {
            self.contextSourceNode.addSubnode(self.contextSourceNode.contentNode)
        }

        func beginAnimation() {
            switch self.source {
            case let .textInput(textInput, replyPanel):
                self.contextSourceNode.isExtractedToContextPreview = true
                self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: nil)
                let sourceAbsoluteRect = textInput.backgroundView.frame.offsetBy(dx: textInput.sourceRect.minX, dy: textInput.sourceRect.minY)

                var sourceReplyPanel: ReplyPanel?
                if let replyPanel = replyPanel, let replyPanelParentView = replyPanel.view.superview {
                    var replySourceAbsoluteFrame = replyPanelParentView.convert(replyPanel.originalFrameBeforeDismissed ?? replyPanel.frame, to: nil)
                    replySourceAbsoluteFrame.origin.x -= sourceAbsoluteRect.minX - self.contextSourceNode.contentRect.minX
                    replySourceAbsoluteFrame.origin.y -= sourceAbsoluteRect.minY - self.contextSourceNode.contentRect.minY

                    sourceReplyPanel = ReplyPanel(titleNode: replyPanel.titleNode, textNode: replyPanel.textNode, lineNode: replyPanel.lineNode, imageNode: replyPanel.imageNode, relativeSourceRect: replySourceAbsoluteFrame)
                }

                self.itemNode.cancelInsertionAnimations()

                let verticalDuration: Double = 0.5
                let horizontalDuration: Double = verticalDuration * 0.7
                let delay: Double = 0.0

                let transition: ContainedViewLayoutTransition = .animated(duration: horizontalDuration, curve: .custom(0.33, 0.0, 0.0, 1.0))

                if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                    itemNode.animateContentFromTextInputField(textInput: textInput, transition: transition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: transition)
                    }
                } else if let itemNode = self.itemNode as? ChatMessageAnimatedStickerItemNode {
                    itemNode.animateContentFromTextInputField(textInput: textInput, transition: transition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: transition)
                    }
                } else if let itemNode = self.itemNode as? ChatMessageStickerItemNode {
                    itemNode.animateContentFromTextInputField(textInput: textInput, transition: transition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: transition)
                    }
                }

                self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)
                self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.minY - targetAbsoluteRect.minY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true, force: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.endAnimation()
                })
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), .custom(0.33, 0.0, 0.0, 1.0), horizontalDuration)
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: sourceAbsoluteRect.minY - targetAbsoluteRect.minY), .custom(0.33, 0.0, 0.0, 1.0), verticalDuration)
                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true)
            case let .stickerMediaInput(stickerMediaInput, replyPanel):
                self.itemNode.cancelInsertionAnimations()

                self.contextSourceNode.isExtractedToContextPreview = true
                self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                let stickerSource: Sticker
                let sourceAbsoluteRect: CGRect
                switch stickerMediaInput {
                case let .inputPanel(sourceItemNode):
                    stickerSource = Sticker(imageNode: sourceItemNode.imageNode, animationNode: sourceItemNode.animationNode, placeholderNode: sourceItemNode.placeholderNode, relativeSourceRect: sourceItemNode.imageNode.frame)
                    sourceAbsoluteRect = sourceItemNode.view.convert(stickerSource.imageNode.frame, to: nil)
                case let .mediaPanel(sourceItemNode):
                    stickerSource = Sticker(imageNode: sourceItemNode.imageNode, animationNode: sourceItemNode.animationNode, placeholderNode: sourceItemNode.placeholderNode, relativeSourceRect: sourceItemNode.imageNode.frame)
                    sourceAbsoluteRect = sourceItemNode.view.convert(stickerSource.imageNode.frame, to: nil)
                case let .inputPanelSearch(sourceItemNode):
                    stickerSource = Sticker(imageNode: sourceItemNode.imageNode, animationNode: sourceItemNode.animationNode, placeholderNode: nil, relativeSourceRect: sourceItemNode.imageNode.frame)
                    sourceAbsoluteRect = sourceItemNode.view.convert(stickerSource.imageNode.frame, to: nil)
                }

                let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: nil)

                var sourceReplyPanel: ReplyPanel?
                if let replyPanel = replyPanel, let replyPanelParentView = replyPanel.view.superview {
                    var replySourceAbsoluteFrame = replyPanelParentView.convert(replyPanel.originalFrameBeforeDismissed ?? replyPanel.frame, to: nil)
                    replySourceAbsoluteFrame.origin.x -= sourceAbsoluteRect.midX - self.contextSourceNode.contentRect.midX
                    replySourceAbsoluteFrame.origin.y -= sourceAbsoluteRect.midY - self.contextSourceNode.contentRect.midY

                    sourceReplyPanel = ReplyPanel(titleNode: replyPanel.titleNode, textNode: replyPanel.textNode, lineNode: replyPanel.lineNode, imageNode: replyPanel.imageNode, relativeSourceRect: replySourceAbsoluteFrame)
                }

                self.itemNode.cancelInsertionAnimations()

                let verticalDuration: Double = 0.5
                let horizontalDuration: Double = verticalDuration * 0.5
                let delay: Double = 0.0

                let transition: ContainedViewLayoutTransition = .animated(duration: horizontalDuration, curve: .custom(0.33, 0.0, 0.0, 1.0))

                if let itemNode = self.itemNode as? ChatMessageAnimatedStickerItemNode {
                    itemNode.animateContentFromStickerGridItem(stickerSource: stickerSource, transition: transition)
                    if let sourceAnimationNode = stickerSource.animationNode {
                        itemNode.animationNode?.setFrameIndex(sourceAnimationNode.currentFrameIndex)
                    }
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: transition)
                    }
                } else if let itemNode = self.itemNode as? ChatMessageStickerItemNode {
                    itemNode.animateContentFromStickerGridItem(stickerSource: stickerSource, transition: transition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: transition)
                    }
                }

                self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)
                self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true, force: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.endAnimation()
                })
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), .custom(0.33, 0.0, 0.0, 1.0), horizontalDuration)
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), .custom(0.33, 0.0, 0.0, 1.0), verticalDuration)
                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true)

                switch stickerMediaInput {
                case .inputPanel:
                    break
                case let .mediaPanel(sourceItemNode):
                    sourceItemNode.isHidden = true
                case let .inputPanelSearch(sourceItemNode):
                    sourceItemNode.isHidden = true
                }
            case let .audioMicInput(audioMicInput):
                if let (container, localRect) = audioMicInput.micButton.contentContainer {
                    let snapshotView = container.snapshotView(afterScreenUpdates: false)
                    if let snapshotView = snapshotView {
                        let sourceAbsoluteRect = container.convert(localRect, to: nil)
                        snapshotView.frame = sourceAbsoluteRect

                        container.isHidden = true

                        let verticalDuration: Double = 0.5
                        let horizontalDuration: Double = verticalDuration * 0.7
                        let delay: Double = 0.0

                        let transition: ContainedViewLayoutTransition = .animated(duration: horizontalDuration, curve: .custom(0.33, 0.0, 0.0, 1.0))

                        if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                            if let contextContainer = itemNode.animateFromMicInput(micInputNode: snapshotView, transition: transition) {
                                self.containerNode.addSubnode(contextContainer.contentNode)

                                let targetAbsoluteRect = contextContainer.view.convert(contextContainer.contentRect, to: nil)

                                self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -contextContainer.contentRect.minX, dy: -contextContainer.contentRect.minY)
                                contextContainer.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)
                                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true, force: true, completion: { [weak self, weak contextContainer, weak container] _ in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    if let contextContainer = contextContainer {
                                        contextContainer.isExtractedToContextPreview = false
                                        contextContainer.isExtractedToContextPreviewUpdated?(false)
                                        contextContainer.addSubnode(contextContainer.contentNode)
                                    }

                                    container?.isHidden = false

                                    strongSelf.endAnimation()
                                })

                                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true)
                            }
                        }
                    }
                }
            }
        }

        private func endAnimation() {
            self.contextSourceNode.isExtractedToContextPreview = false
            self.contextSourceNode.isExtractedToContextPreviewUpdated?(false)
            
            self.animationEnded?()
        }

        func addExternalOffset(offset: CGFloat, transition: ContainedViewLayoutTransition, itemNode: ListViewItemNode?) {
            var applyOffset = false
            if let itemNode = itemNode {
                if itemNode === self.itemNode {
                    applyOffset = true
                }
            } else {
                applyOffset = true
            }
            if applyOffset {
                self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: -offset)
                transition.animateOffsetAdditive(node: self.scrollingContainer, offset: offset)
            }
        }
    }

    private let listNode: ChatHistoryListNode

    private var currentPendingItem: (Int64, Source, () -> Void)?

    private var animatingItemNodes: [AnimatingItemNode] = []

    init(listNode: ChatHistoryListNode) {
        self.listNode = listNode

        super.init()

        self.listNode.animationCorrelationMessageFound = { [weak self] itemNode, correlationId in
            guard let strongSelf = self, let (currentId, currentSource, initiated) = strongSelf.currentPendingItem else {
                return
            }
            if currentId == correlationId {
                strongSelf.currentPendingItem = nil
                strongSelf.beginAnimation(itemNode: itemNode, source: currentSource)
                initiated()
            }
        }
    }

    func add(correlationId: Int64, source: Source, initiated: @escaping () -> Void) {
        self.currentPendingItem = (correlationId, source, initiated)
        self.listNode.setCurrentSendAnimationCorrelationId(correlationId)
    }

    private func beginAnimation(itemNode: ChatMessageItemView, source: Source) {
        var contextSourceNode: ContextExtractedContentContainingNode?
        if let itemNode = itemNode as? ChatMessageBubbleItemNode {
            contextSourceNode = itemNode.mainContextSourceNode
        } else if let itemNode = itemNode as? ChatMessageStickerItemNode {
            contextSourceNode = itemNode.contextSourceNode
        } else if let itemNode = itemNode as? ChatMessageAnimatedStickerItemNode {
            contextSourceNode = itemNode.contextSourceNode
        }

        if let contextSourceNode = contextSourceNode {
            let animatingItemNode = AnimatingItemNode(itemNode: itemNode, contextSourceNode: contextSourceNode, source: source)
            self.animatingItemNodes.append(animatingItemNode)
            if case .audioMicInput = source {
                let overlayController = OverlayTransitionContainerController()
                overlayController.displayNode.addSubnode(animatingItemNode)
                animatingItemNode.overlayController = overlayController
                itemNode.item?.context.sharedContext.mainWindow?.presentInGlobalOverlay(overlayController)
            } else {
                self.addSubnode(animatingItemNode)
            }

            animatingItemNode.animationEnded = { [weak self, weak animatingItemNode] in
                guard let strongSelf = self, let animatingItemNode = animatingItemNode else {
                    return
                }
                animatingItemNode.removeFromSupernode()
                animatingItemNode.overlayController?.dismiss()
                if let index = strongSelf.animatingItemNodes.firstIndex(where: { $0 === animatingItemNode }) {
                    strongSelf.animatingItemNodes.remove(at: index)
                }
            }

            animatingItemNode.frame = self.bounds
            animatingItemNode.beginAnimation()
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }

    func addExternalOffset(offset: CGFloat, transition: ContainedViewLayoutTransition, itemNode: ListViewItemNode?) {
        for animatingItemNode in self.animatingItemNodes {
            animatingItemNode.addExternalOffset(offset: offset, transition: transition, itemNode: itemNode)
        }
    }
}
