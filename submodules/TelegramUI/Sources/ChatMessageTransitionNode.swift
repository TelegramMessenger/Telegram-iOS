import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import AnimatedStickerNode
import SwiftSignalKit
import ContextUI
import Postbox
import TelegramCore
import ReactionSelectionNode

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

public final class ChatMessageTransitionNode: ASDisplayNode {
    static let animationDuration: Double = 0.3

    static let verticalAnimationControlPoints: (Float, Float, Float, Float) = (0.19919472913616398, 0.010644531250000006, 0.27920937042459737, 0.91025390625)
    static let verticalAnimationCurve: ContainedViewLayoutTransitionCurve = .custom(verticalAnimationControlPoints.0, verticalAnimationControlPoints.1, verticalAnimationControlPoints.2, verticalAnimationControlPoints.3)
    static let horizontalAnimationCurve: ContainedViewLayoutTransitionCurve = .custom(0.23, 1.0, 0.32, 1.0)

    final class ReplyPanel {
        let titleNode: ASDisplayNode
        let textNode: ASDisplayNode
        let lineNode: ASDisplayNode
        let imageNode: ASDisplayNode
        let relativeSourceRect: CGRect
        let relativeTargetRect: CGRect

        init(titleNode: ASDisplayNode, textNode: ASDisplayNode, lineNode: ASDisplayNode, imageNode: ASDisplayNode, relativeSourceRect: CGRect, relativeTargetRect: CGRect) {
            self.titleNode = titleNode
            self.textNode = textNode
            self.lineNode = lineNode
            self.imageNode = imageNode
            self.relativeSourceRect = relativeSourceRect
            self.relativeTargetRect = relativeTargetRect
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
            let scrollOffset: CGFloat

            init(backgroundView: UIView, contentView: UIView, sourceRect: CGRect, scrollOffset: CGFloat) {
                self.backgroundView = backgroundView
                self.contentView = contentView
                self.sourceRect = sourceRect
                self.scrollOffset = scrollOffset
            }
        }

        enum StickerInput {
            case inputPanel(itemNode: ChatMediaInputStickerGridItemNode)
            case mediaPanel(itemNode: HorizontalStickerGridItemNode)
            case inputPanelSearch(itemNode: StickerPaneSearchStickerItemNode)
            case emptyPanel(itemNode: ChatEmptyNodeStickerContentNode)
        }

        final class AudioMicInput {
            let micButton: ChatTextInputMediaRecordingButton

            init(micButton: ChatTextInputMediaRecordingButton) {
                self.micButton = micButton
            }
        }

        final class VideoMessage {
            let view: UIView

            init(view: UIView) {
                self.view = view
            }
        }

        final class MediaInput {
            let extractSnapshot: () -> UIView?

            init(extractSnapshot: @escaping () -> UIView?) {
                self.extractSnapshot = extractSnapshot
            }
        }
        
        final class GroupedMediaInput {
            let extractSnapshots: () -> [UIView]

            init(extractSnapshots: @escaping () -> [UIView]) {
                self.extractSnapshots = extractSnapshots
            }
        }

        case textInput(textInput: TextInput, replyPanel: ReplyAccessoryPanelNode?)
        case stickerMediaInput(input: StickerInput, replyPanel: ReplyAccessoryPanelNode?)
        case audioMicInput(AudioMicInput)
        case videoMessage(VideoMessage)
        case mediaInput(MediaInput)
        case groupedMediaInput(GroupedMediaInput)
    }
            
    final class DecorationItemNode: ASDisplayNode {
        let itemNode: ChatMessageItemView
        let contentView: UIView
        private let getContentAreaInScreenSpace: () -> CGRect
        
        private let scrollingContainer: ASDisplayNode
        private let containerNode: ASDisplayNode
        private let clippingNode: ASDisplayNode
        
        fileprivate weak var overlayController: OverlayTransitionContainerController?
        
        init(itemNode: ChatMessageItemView, contentView: UIView, getContentAreaInScreenSpace: @escaping () -> CGRect) {
            self.itemNode = itemNode
            self.contentView = contentView
            self.getContentAreaInScreenSpace = getContentAreaInScreenSpace
            
            self.clippingNode = ASDisplayNode()
            self.clippingNode.clipsToBounds = true
            
            self.scrollingContainer = ASDisplayNode()
            self.containerNode = ASDisplayNode()
            
            super.init()
            
            self.addSubnode(self.clippingNode)
            self.clippingNode.addSubnode(self.scrollingContainer)
            self.scrollingContainer.addSubnode(self.containerNode)
            self.containerNode.view.addSubview(self.contentView)
        }
        
        func updateLayout(size: CGSize) {
            self.clippingNode.frame = CGRect(origin: CGPoint(), size: size)
            
            let absoluteRect = self.itemNode.view.convert(self.itemNode.view.bounds, to: self.itemNode.supernode?.supernode?.view)
            self.containerNode.frame = absoluteRect
        }
        
        func addExternalOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
            if transition.isAnimated {
                assert(true)
            }
            self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: -offset)
            transition.animateOffsetAdditive(node: self.scrollingContainer, offset: offset)
        }

        func addContentOffset(offset: CGFloat) {
            self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: offset)
        }
    }

    private final class AnimatingItemNode: ASDisplayNode {
        let itemNode: ChatMessageItemView
        private let contextSourceNode: ContextExtractedContentContainingNode
        private let source: ChatMessageTransitionNode.Source
        private let getContentAreaInScreenSpace: () -> CGRect

        private let scrollingContainer: ASDisplayNode
        private let containerNode: ASDisplayNode
        private let clippingNode: ASDisplayNode

        weak var overlayController: OverlayTransitionContainerController?

        var animationEnded: (() -> Void)?
        var updateAfterCompletion: Bool = false

        init(itemNode: ChatMessageItemView, contextSourceNode: ContextExtractedContentContainingNode, source: ChatMessageTransitionNode.Source, getContentAreaInScreenSpace: @escaping () -> CGRect) {
            self.itemNode = itemNode
            self.getContentAreaInScreenSpace = getContentAreaInScreenSpace

            self.clippingNode = ASDisplayNode()
            self.clippingNode.clipsToBounds = true

            self.scrollingContainer = ASDisplayNode()
            self.containerNode = ASDisplayNode()
            self.contextSourceNode = contextSourceNode
            self.source = source

            super.init()

            self.addSubnode(self.clippingNode)
            self.clippingNode.addSubnode(self.scrollingContainer)
            self.scrollingContainer.addSubnode(self.containerNode)
        }

        deinit {
            self.contextSourceNode.addSubnode(self.contextSourceNode.contentNode)
        }

        func updateLayout(size: CGSize) {
            self.clippingNode.frame = CGRect(origin: CGPoint(), size: size)
        }

        func beginAnimation() {
            let verticalDuration: Double = ChatMessageTransitionNode.animationDuration
            let horizontalDuration: Double = verticalDuration
            let delay: Double = 0.0

            var updatedContentAreaInScreenSpace = self.getContentAreaInScreenSpace()
            updatedContentAreaInScreenSpace.size.width = updatedContentAreaInScreenSpace.origin.x + self.clippingNode.bounds.width
            updatedContentAreaInScreenSpace.origin.x = 0.0

            let clippingOffset = updatedContentAreaInScreenSpace.minY - self.clippingNode.frame.minY
            self.clippingNode.frame = CGRect(origin: CGPoint(x: 0.0, y: updatedContentAreaInScreenSpace.minY), size: CGSize(width: updatedContentAreaInScreenSpace.size.width, height: self.clippingNode.bounds.height))
            self.clippingNode.bounds = CGRect(origin: CGPoint(x: 0.0, y: clippingOffset), size: self.clippingNode.bounds.size)

            switch self.source {
            case let .textInput(initialTextInput, replyPanel):
                self.contextSourceNode.isExtractedToContextPreview = true
                self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                var currentContentRect = self.contextSourceNode.contentRect
                let contextSourceNode = self.contextSourceNode
                self.contextSourceNode.layoutUpdated = { [weak self, weak contextSourceNode] size, _ in
                    guard let strongSelf = self, let contextSourceNode = contextSourceNode, strongSelf.contextSourceNode === contextSourceNode else {
                        return
                    }
                    let updatedContentRect = contextSourceNode.contentRect
                    let deltaY = updatedContentRect.height - currentContentRect.height
                    if !deltaY.isZero {
                        currentContentRect = updatedContentRect
                        strongSelf.addContentOffset(offset: deltaY, itemNode: nil)
                    }
                }

                self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: self.view)

                let sourceRect = self.view.convert(initialTextInput.sourceRect, from: nil)
                let sourceBackgroundAbsoluteRect = initialTextInput.backgroundView.frame.offsetBy(dx: sourceRect.minX, dy: sourceRect.minY)
                let sourceAbsoluteRect = CGRect(origin: CGPoint(x: sourceBackgroundAbsoluteRect.minX, y: sourceBackgroundAbsoluteRect.maxY - self.contextSourceNode.contentRect.height), size: self.contextSourceNode.contentRect.size)

                let textInput = ChatMessageTransitionNode.Source.TextInput(backgroundView: initialTextInput.backgroundView, contentView: initialTextInput.contentView, sourceRect: sourceRect, scrollOffset: initialTextInput.scrollOffset)

                textInput.backgroundView.frame = CGRect(origin: CGPoint(x: 0.0, y: sourceAbsoluteRect.height - sourceBackgroundAbsoluteRect.height), size: textInput.backgroundView.bounds.size)
                textInput.contentView.frame = textInput.contentView.frame.offsetBy(dx: 0.0, dy: sourceAbsoluteRect.height - sourceBackgroundAbsoluteRect.height)

                var sourceReplyPanel: ReplyPanel?
                if let replyPanel = replyPanel, let replyPanelParentView = replyPanel.view.superview {
                    let replyPanelFrame = replyPanel.originalFrameBeforeDismissed ?? replyPanel.frame
                    var replySourceAbsoluteFrame = replyPanelParentView.convert(replyPanelFrame, to: self.view)

                    replySourceAbsoluteFrame.origin.x -= sourceAbsoluteRect.minX - self.contextSourceNode.contentRect.minX
                    replySourceAbsoluteFrame.origin.y -= sourceAbsoluteRect.minY - self.contextSourceNode.contentRect.minY

                    var globalTargetFrame = replySourceAbsoluteFrame.offsetBy(dx: 0.0, dy: replyPanelFrame.height)

                    globalTargetFrame.origin.x += sourceAbsoluteRect.minX - targetAbsoluteRect.minX
                    globalTargetFrame.origin.y += sourceAbsoluteRect.minY - targetAbsoluteRect.minY

                    sourceReplyPanel = ReplyPanel(titleNode: replyPanel.titleNode, textNode: replyPanel.textNode, lineNode: replyPanel.lineNode, imageNode: replyPanel.imageNode, relativeSourceRect: replySourceAbsoluteFrame, relativeTargetRect: globalTargetFrame)
                }

                self.itemNode.cancelInsertionAnimations()

                let horizontalCurve = ChatMessageTransitionNode.horizontalAnimationCurve
                let horizontalTransition: ContainedViewLayoutTransition = .animated(duration: horizontalDuration, curve: horizontalCurve)
                let verticalCurve = ChatMessageTransitionNode.verticalAnimationCurve
                let verticalTransition: ContainedViewLayoutTransition = .animated(duration: verticalDuration, curve: verticalCurve)

                let combinedTransition = CombinedTransition(horizontal: horizontalTransition, vertical: verticalTransition)

                self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)
                self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.maxY - targetAbsoluteRect.maxY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: verticalCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.endAnimation()
                })
                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: horizontalCurve.mediaTimingFunction, additive: true)
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), horizontalCurve, horizontalDuration)
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: sourceAbsoluteRect.maxY - targetAbsoluteRect.maxY), verticalCurve, verticalDuration)

                if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                    itemNode.animateContentFromTextInputField(textInput: textInput, transition: combinedTransition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: combinedTransition)
                    }
                } else if let itemNode = self.itemNode as? ChatMessageAnimatedStickerItemNode {
                    itemNode.animateContentFromTextInputField(textInput: textInput, transition: combinedTransition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: combinedTransition)
                    }
                } else if let itemNode = self.itemNode as? ChatMessageStickerItemNode {
                    itemNode.animateContentFromTextInputField(textInput: textInput, transition: combinedTransition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: combinedTransition)
                    }
                }
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
                    sourceAbsoluteRect = sourceItemNode.view.convert(stickerSource.imageNode.frame, to: self.view)
                case let .mediaPanel(sourceItemNode):
                    stickerSource = Sticker(imageNode: sourceItemNode.imageNode, animationNode: sourceItemNode.animationNode, placeholderNode: sourceItemNode.placeholderNode, relativeSourceRect: sourceItemNode.imageNode.frame)
                    sourceAbsoluteRect = sourceItemNode.view.convert(stickerSource.imageNode.frame, to: self.view)
                case let .inputPanelSearch(sourceItemNode):
                    stickerSource = Sticker(imageNode: sourceItemNode.imageNode, animationNode: sourceItemNode.animationNode, placeholderNode: nil, relativeSourceRect: sourceItemNode.imageNode.frame)
                    sourceAbsoluteRect = sourceItemNode.view.convert(stickerSource.imageNode.frame, to: self.view)
                case let .emptyPanel(sourceItemNode):
                    stickerSource = Sticker(imageNode: sourceItemNode.stickerNode.imageNode, animationNode: sourceItemNode.stickerNode.animationNode, placeholderNode: nil, relativeSourceRect: sourceItemNode.stickerNode.imageNode.frame)
                    sourceAbsoluteRect = sourceItemNode.stickerNode.view.convert(sourceItemNode.stickerNode.imageNode.frame, to: self.view)
                }

                let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: self.view)

                var sourceReplyPanel: ReplyPanel?
                if let replyPanel = replyPanel, let replyPanelParentView = replyPanel.view.superview {
                    var replySourceAbsoluteFrame = replyPanelParentView.convert(replyPanel.originalFrameBeforeDismissed ?? replyPanel.frame, to: self.view)
                    replySourceAbsoluteFrame.origin.x -= sourceAbsoluteRect.midX - self.contextSourceNode.contentRect.midX
                    replySourceAbsoluteFrame.origin.y -= sourceAbsoluteRect.midY - self.contextSourceNode.contentRect.midY

                    sourceReplyPanel = ReplyPanel(titleNode: replyPanel.titleNode, textNode: replyPanel.textNode, lineNode: replyPanel.lineNode, imageNode: replyPanel.imageNode, relativeSourceRect: replySourceAbsoluteFrame, relativeTargetRect: replySourceAbsoluteFrame.offsetBy(dx: 0.0, dy: replySourceAbsoluteFrame.height))
                }

                let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNode.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNode.verticalAnimationCurve))

                if let itemNode = self.itemNode as? ChatMessageAnimatedStickerItemNode {
                    itemNode.animateContentFromStickerGridItem(stickerSource: stickerSource, transition: combinedTransition)
                    if let sourceAnimationNode = stickerSource.animationNode {
                        itemNode.animationNode?.setFrameIndex(sourceAnimationNode.currentFrameIndex)
                    }
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: combinedTransition)
                    }
                } else if let itemNode = self.itemNode as? ChatMessageStickerItemNode {
                    itemNode.animateContentFromStickerGridItem(stickerSource: stickerSource, transition: combinedTransition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: combinedTransition)
                    }
                }

                self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)
                self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.verticalAnimationCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.endAnimation()
                })
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), ChatMessageTransitionNode.horizontalAnimationCurve, horizontalDuration)
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), ChatMessageTransitionNode.verticalAnimationCurve, verticalDuration)
                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.horizontalAnimationCurve.mediaTimingFunction, additive: true)

                switch stickerMediaInput {
                case .inputPanel:
                    break
                case let .mediaPanel(sourceItemNode):
                    sourceItemNode.isHidden = true
                case let .inputPanelSearch(sourceItemNode):
                    sourceItemNode.isHidden = true
                case let .emptyPanel(sourceItemNode):
                    sourceItemNode.isHidden = true
                }
            case let .audioMicInput(audioMicInput):
                if let (container, localRect) = audioMicInput.micButton.contentContainer {
                    let snapshotView = container.snapshotView(afterScreenUpdates: false)
                    if let snapshotView = snapshotView {
                        let sourceAbsoluteRect = container.convert(localRect, to: self.view)
                        snapshotView.frame = sourceAbsoluteRect

                        container.isHidden = true

                        let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNode.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNode.verticalAnimationCurve))

                        if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                            if let contextContainer = itemNode.animateFromMicInput(micInputNode: snapshotView, transition: combinedTransition) {
                                self.containerNode.addSubnode(contextContainer.contentNode)

                                let targetAbsoluteRect = contextContainer.view.convert(contextContainer.contentRect, to: self.view)

                                self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -contextContainer.contentRect.minX, dy: -contextContainer.contentRect.minY)
                                contextContainer.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)
                                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.verticalAnimationCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self, weak contextContainer, weak container] _ in
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

                                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.horizontalAnimationCurve.mediaTimingFunction, additive: true)
                            }
                        }
                    }
                }
            case let .videoMessage(videoMessage):
                let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNode.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNode.verticalAnimationCurve))

                if let itemNode = self.itemNode as? ChatMessageInstantVideoItemNode {
                    itemNode.cancelInsertionAnimations()

                    self.contextSourceNode.isExtractedToContextPreview = true
                    self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                    self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                    let sourceAbsoluteRect = videoMessage.view.frame
                    let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: self.view)

                    videoMessage.view.frame = videoMessage.view.frame.offsetBy(dx: targetAbsoluteRect.midX - sourceAbsoluteRect.midX, dy: targetAbsoluteRect.midY - sourceAbsoluteRect.midY)

                    self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)
                    self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.horizontalAnimationCurve.mediaTimingFunction, additive: true, force: true)

                    self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.verticalAnimationCurve.mediaTimingFunction, additive: true, completion: { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }

                        strongSelf.endAnimation()
                    })

                    itemNode.animateFromSnapshot(snapshotView: videoMessage.view, transition: combinedTransition)
                }
            case let .mediaInput(mediaInput):
                if let snapshotView = mediaInput.extractSnapshot() {
                    Queue.mainQueue().justDispatch {
                        if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                            itemNode.cancelInsertionAnimations()

                            self.contextSourceNode.isExtractedToContextPreview = true
                            self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                            self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                            let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: self.view)
                            let sourceBackgroundAbsoluteRect = snapshotView.frame
                            let sourceAbsoluteRect = CGRect(origin: CGPoint(x: sourceBackgroundAbsoluteRect.midX - self.contextSourceNode.contentRect.size.width / 2.0, y: sourceBackgroundAbsoluteRect.midY - self.contextSourceNode.contentRect.size.height / 2.0), size: self.contextSourceNode.contentRect.size)

                            let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNode.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNode.verticalAnimationCurve))

                            if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                                itemNode.animateContentFromMediaInput(snapshotView: snapshotView, transition: combinedTransition)
                            }

                            self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)

                            snapshotView.center = targetAbsoluteRect.center.offsetBy(dx: -self.containerNode.frame.minX, dy: -self.containerNode.frame.minY)
                            self.containerNode.view.addSubview(snapshotView)

                            self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)

                            self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.horizontalAnimationCurve.mediaTimingFunction, additive: true, force: true)
                            self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.verticalAnimationCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self] _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.endAnimation()
                            })

                            combinedTransition.horizontal.animateTransformScale(node: self.contextSourceNode.contentNode, from: CGPoint(x: sourceBackgroundAbsoluteRect.width / targetAbsoluteRect.width, y: sourceBackgroundAbsoluteRect.height / targetAbsoluteRect.height))

                            combinedTransition.horizontal.updateTransformScale(layer: snapshotView.layer, scale: CGPoint(x: 1.0 / (sourceBackgroundAbsoluteRect.width / targetAbsoluteRect.width), y: 1.0 / (sourceBackgroundAbsoluteRect.height / targetAbsoluteRect.height)))

                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })

                            self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), ChatMessageTransitionNode.horizontalAnimationCurve, horizontalDuration)
                            self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: sourceAbsoluteRect.maxY - targetAbsoluteRect.maxY), ChatMessageTransitionNode.verticalAnimationCurve, verticalDuration)
                        }
                    }
                } else {
                    self.endAnimation()
                }
            case let .groupedMediaInput(groupedMediaInput):
                let snapshotViews = groupedMediaInput.extractSnapshots()
                if snapshotViews.isEmpty {
                    self.endAnimation()
                    return
                }
                Queue.mainQueue().justDispatch {
                    if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                        itemNode.cancelInsertionAnimations()

                        self.contextSourceNode.isExtractedToContextPreview = true
                        self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                        self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                        let combinedTransition = CombinedTransition(horizontal: .animated(duration: horizontalDuration, curve: ChatMessageTransitionNode.horizontalAnimationCurve), vertical: .animated(duration: verticalDuration, curve: ChatMessageTransitionNode.verticalAnimationCurve))

                        var targetContentRects: [CGRect] = []
                        if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                            targetContentRects = itemNode.animateContentFromGroupedMediaInput(transition: combinedTransition)
                        }
                        
                        let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: self.view)

                        func boundingRect(for views: [UIView]) -> CGRect {
                            var minX: CGFloat = .greatestFiniteMagnitude
                            var minY: CGFloat = .greatestFiniteMagnitude
                            var maxX: CGFloat = .leastNonzeroMagnitude
                            var maxY: CGFloat = .leastNonzeroMagnitude

                            for view in views {
                                let rect = view.frame
                                if rect.minX < minX {
                                    minX = rect.minX
                                }
                                if rect.minY < minY {
                                    minY = rect.minY
                                }
                                if rect.maxX > maxX {
                                    maxX = rect.maxX
                                }
                                if rect.maxY > maxY {
                                    maxY = rect.maxY
                                }
                            }
                            return CGRect(origin: CGPoint(x: minX, y: minY), size: CGSize(width: maxX - minX, height: maxY - minY))
                        }

                        let sourceBackgroundAbsoluteRect = boundingRect(for: snapshotViews)
                        let sourceAbsoluteRect = CGRect(origin: CGPoint(x: sourceBackgroundAbsoluteRect.midX - self.contextSourceNode.contentRect.size.width / 2.0, y: sourceBackgroundAbsoluteRect.midY - self.contextSourceNode.contentRect.size.height / 2.0), size: self.contextSourceNode.contentRect.size)

                        self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)

                        self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)

                        self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.horizontalAnimationCurve.mediaTimingFunction, additive: true, force: true)
                        self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: ChatMessageTransitionNode.verticalAnimationCurve.mediaTimingFunction, additive: true, force: true, completion: { [weak self] _ in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.endAnimation()
                        })

                        combinedTransition.horizontal.animateTransformScale(node: self.contextSourceNode.contentNode, from: CGPoint(x: sourceBackgroundAbsoluteRect.width / targetAbsoluteRect.width, y: sourceBackgroundAbsoluteRect.height / targetAbsoluteRect.height))

                        var index = 0
                        for snapshotView in snapshotViews {
                            let targetContentRect = targetContentRects[index]
                            let targetAbsoluteContentRect = targetContentRect.offsetBy(dx: targetAbsoluteRect.minX, dy: targetAbsoluteRect.minY)
                            
                            snapshotView.center = targetAbsoluteContentRect.center.offsetBy(dx: -self.containerNode.frame.minX, dy: -self.containerNode.frame.minY)
                            self.containerNode.view.addSubview(snapshotView)
                        
                            combinedTransition.horizontal.updateTransformScale(layer: snapshotView.layer, scale: CGPoint(x: 1.0 / (snapshotView.frame.width / targetContentRect.width), y: 1.0 / (snapshotView.frame.height / targetContentRect.height)))
                            
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            
                            index += 1
                        }
                        
                        self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), ChatMessageTransitionNode.horizontalAnimationCurve, horizontalDuration)
                        self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: sourceAbsoluteRect.maxY - targetAbsoluteRect.maxY), ChatMessageTransitionNode.verticalAnimationCurve, verticalDuration)
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
                if transition.isAnimated {
                    assert(true)
                }
                self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: -offset)
                transition.animateOffsetAdditive(node: self.scrollingContainer, offset: offset)
            }
        }

        func addContentOffset(offset: CGFloat, itemNode: ListViewItemNode?) {
            var applyOffset = false
            if let itemNode = itemNode {
                if itemNode === self.itemNode {
                    applyOffset = true
                }
            } else {
                applyOffset = true
            }
            if applyOffset {
                self.scrollingContainer.bounds = self.scrollingContainer.bounds.offsetBy(dx: 0.0, dy: offset)
            }
        }
    }
    
    private final class MessageReactionContext {
        private(set) weak var itemNode: ListViewItemNode?
        private(set) weak var contextController: ContextController?
        private(set) weak var standaloneReactionAnimation: StandaloneReactionAnimation?
        
        var isEmpty: Bool {
            return self.contextController == nil && self.standaloneReactionAnimation == nil
        }
        
        init(itemNode: ListViewItemNode, contextController: ContextController?, standaloneReactionAnimation: StandaloneReactionAnimation?) {
            self.itemNode = itemNode
            self.contextController = contextController
            self.standaloneReactionAnimation = standaloneReactionAnimation
        }
        
        func addExternalOffset(offset: CGFloat, transition: ContainedViewLayoutTransition, itemNode: ListViewItemNode?) {
            guard let currentItemNode = self.itemNode else {
                return
            }
            if itemNode == nil || itemNode === currentItemNode {
                if let contextController = self.contextController {
                    contextController.addRelativeContentOffset(CGPoint(x: 0.0, y: -offset), transition: transition)
                }
                if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                    standaloneReactionAnimation.addRelativeContentOffset(CGPoint(x: 0.0, y: -offset), transition: transition)
                }
            }
        }

        func addContentOffset(offset: CGFloat, itemNode: ListViewItemNode?) {
        }
        
        func dismiss() {
            if let contextController = self.contextController {
                contextController.cancelReactionAnimation()
                contextController.view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak contextController] _ in
                    contextController?.dismissNow()
                })
            }
            if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                standaloneReactionAnimation.cancel()
                standaloneReactionAnimation.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak standaloneReactionAnimation] _ in
                    standaloneReactionAnimation?.removeFromSupernode()
                })
            }
        }
    }

    private let listNode: ChatHistoryListNode
    private let getContentAreaInScreenSpace: () -> CGRect
    private let onTransitionEvent: (ContainedViewLayoutTransition) -> Void

    private var currentPendingItems: [Int64: (Source, () -> Void)] = [:]

    private var animatingItemNodes: [AnimatingItemNode] = []
    private var decorationItemNodes: [DecorationItemNode] = []
    private var messageReactionContexts: [MessageReactionContext] = []

    var hasScheduledTransitions: Bool {
        return !self.currentPendingItems.isEmpty
    }

    var hasOngoingTransitions: Bool {
        return !self.animatingItemNodes.isEmpty
    }

    init(listNode: ChatHistoryListNode, getContentAreaInScreenSpace: @escaping () -> CGRect, onTransitionEvent: @escaping (ContainedViewLayoutTransition) -> Void) {
        self.listNode = listNode
        self.getContentAreaInScreenSpace = getContentAreaInScreenSpace
        self.onTransitionEvent = onTransitionEvent

        super.init()

        self.listNode.animationCorrelationMessagesFound = { [weak self] itemNodeAndCorrelationIds in
            guard let strongSelf = self else {
                return
            }
            
            for (correlationId, itemNode) in itemNodeAndCorrelationIds {
                if let (currentSource, initiated) = strongSelf.currentPendingItems[correlationId] {
                    strongSelf.beginAnimation(itemNode: itemNode, source: currentSource)
                    initiated()
                }
            }
            
            if itemNodeAndCorrelationIds.count == strongSelf.currentPendingItems.count {
                strongSelf.currentPendingItems = [:]
            }
        }
    }

    func add(correlationId: Int64, source: Source, initiated: @escaping () -> Void) {
        self.currentPendingItems = [correlationId: (source, initiated)]
        self.listNode.setCurrentSendAnimationCorrelationIds(Set([correlationId]))
    }
    
    func add(grouped: [(correlationId: Int64, source: Source, initiated: () -> Void)]) {
        var currentPendingItems: [Int64: (Source, () -> Void)] = [:]
        var correlationIds = Set<Int64>()
        for (correlationId, source, initiated) in grouped {
            currentPendingItems[correlationId] = (source, initiated)
            correlationIds.insert(correlationId)
        }
        
        self.currentPendingItems = currentPendingItems
        self.listNode.setCurrentSendAnimationCorrelationIds(correlationIds)
    }
    
    func add(decorationView: UIView, itemNode: ChatMessageItemView) -> DecorationItemNode {
        let decorationItemNode = DecorationItemNode(itemNode: itemNode, contentView: decorationView, getContentAreaInScreenSpace: self.getContentAreaInScreenSpace)
        decorationItemNode.updateLayout(size: self.bounds.size)
       
        self.decorationItemNodes.append(decorationItemNode)
        self.addSubnode(decorationItemNode)
        
//        let overlayController = OverlayTransitionContainerController()
//        overlayController.displayNode.isUserInteractionEnabled = false
//        overlayController.displayNode.addSubnode(decorationItemNode)
//        decorationItemNode.overlayController = overlayController
//        itemNode.item?.context.sharedContext.mainWindow?.presentInGlobalOverlay(overlayController)
                
        return decorationItemNode
    }
    
    func remove(decorationNode: DecorationItemNode) {
        self.decorationItemNodes.removeAll(where: { $0 === decorationNode })
        decorationNode.removeFromSupernode()
        decorationNode.overlayController?.dismiss()
    }

    private func beginAnimation(itemNode: ChatMessageItemView, source: Source) {
        var contextSourceNode: ContextExtractedContentContainingNode?
        if let itemNode = itemNode as? ChatMessageBubbleItemNode {
            contextSourceNode = itemNode.mainContextSourceNode
        } else if let itemNode = itemNode as? ChatMessageStickerItemNode {
            contextSourceNode = itemNode.contextSourceNode
        } else if let itemNode = itemNode as? ChatMessageAnimatedStickerItemNode {
            contextSourceNode = itemNode.contextSourceNode
        } else if let itemNode = itemNode as? ChatMessageInstantVideoItemNode {
            contextSourceNode = itemNode.contextSourceNode
        }

        if let contextSourceNode = contextSourceNode {
            let animatingItemNode = AnimatingItemNode(itemNode: itemNode, contextSourceNode: contextSourceNode, source: source, getContentAreaInScreenSpace: self.getContentAreaInScreenSpace)
            animatingItemNode.updateLayout(size: self.bounds.size)
            
            self.animatingItemNodes.append(animatingItemNode)
            switch source {
            case .audioMicInput, .videoMessage, .mediaInput, .groupedMediaInput:
                let overlayController = OverlayTransitionContainerController()
                overlayController.displayNode.addSubnode(animatingItemNode)
                animatingItemNode.overlayController = overlayController
                itemNode.item?.context.sharedContext.mainWindow?.presentInGlobalOverlay(overlayController)
            default:
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

                if animatingItemNode.updateAfterCompletion, let item = animatingItemNode.itemNode.item {
                    for (message, _) in item.content {
                        strongSelf.listNode.requestMessageUpdate(stableId: message.stableId)
                        break
                    }
                }
            }

            animatingItemNode.frame = self.bounds
            animatingItemNode.beginAnimation()

            self.onTransitionEvent(.animated(duration: ChatMessageTransitionNode.animationDuration, curve: ChatMessageTransitionNode.verticalAnimationCurve))
        }
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
    
    private func removeEmptyMessageReactionContexts() {
        for i in (0 ..< self.messageReactionContexts.count).reversed() {
            if self.messageReactionContexts[i].isEmpty {
                self.messageReactionContexts.remove(at: i)
            }
        }
    }
    
    func dismissMessageReactionContexts(itemNode: ListViewItemNode? = nil) {
        for i in (0 ..< self.messageReactionContexts.count).reversed() {
            let messageReactionContext = self.messageReactionContexts[i]
            if itemNode == nil || messageReactionContext.itemNode === itemNode {
                self.messageReactionContexts.remove(at: i)
                messageReactionContext.dismiss()
            }
        }
    }
    
    func addMessageContextController(messageId: MessageId, contextController: ContextController) {
        self.addMessageReactionContextContext(messageId: messageId, contextController: contextController, standaloneReactionAnimation: nil)
    }
    
    func addMessageStandaloneReactionAnimation(messageId: MessageId, standaloneReactionAnimation: StandaloneReactionAnimation) {
        self.addMessageReactionContextContext(messageId: messageId, contextController: nil, standaloneReactionAnimation: standaloneReactionAnimation)
    }
    
    private func addMessageReactionContextContext(messageId: MessageId, contextController: ContextController?, standaloneReactionAnimation: StandaloneReactionAnimation?) {
        self.removeEmptyMessageReactionContexts()
        
        var messageItemNode: ListViewItemNode?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                if let item = itemNode.item {
                    for (message, _) in item.content {
                        if message.id == messageId {
                            messageItemNode = itemNode
                            break
                        }
                    }
                }
            }
        }
        
        if let messageItemNode = messageItemNode {
            for i in 0 ..< self.messageReactionContexts.count {
                if self.messageReactionContexts[i].itemNode === messageItemNode {
                    self.messageReactionContexts[i].dismiss()
                    self.messageReactionContexts.remove(at: i)
                    break
                }
            }
            self.messageReactionContexts.append(MessageReactionContext(itemNode: messageItemNode, contextController: contextController, standaloneReactionAnimation: standaloneReactionAnimation))
        }
    }

    func addExternalOffset(offset: CGFloat, transition: ContainedViewLayoutTransition, itemNode: ListViewItemNode?) {
        for animatingItemNode in self.animatingItemNodes {
            animatingItemNode.addExternalOffset(offset: offset, transition: transition, itemNode: itemNode)
        }
        if itemNode == nil {
            for decorationItemNode in self.decorationItemNodes {
                decorationItemNode.addExternalOffset(offset: offset, transition: transition)
            }
        }
        for messageReactionContext in self.messageReactionContexts {
            messageReactionContext.addExternalOffset(offset: offset, transition: transition, itemNode: itemNode)
        }
    }

    func addContentOffset(offset: CGFloat, itemNode: ListViewItemNode?) {
        for animatingItemNode in self.animatingItemNodes {
            animatingItemNode.addContentOffset(offset: offset, itemNode: itemNode)
        }
        if itemNode == nil {
            for decorationItemNode in self.decorationItemNodes {
                decorationItemNode.addContentOffset(offset: offset)
            }
        }
        for messageReactionContext in self.messageReactionContexts {
            messageReactionContext.addContentOffset(offset: offset, itemNode: itemNode)
        }
    }

    func isAnimatingMessage(stableId: UInt32) -> Bool {
        for itemNode in self.animatingItemNodes {
            if let item = itemNode.itemNode.item {
                for (message, _) in item.content {
                    if message.stableId == stableId {
                        return true
                    }
                }
            }
        }
        return false
    }

    func scheduleUpdateMessageAfterAnimationCompleted(stableId: UInt32) {
        for itemNode in self.animatingItemNodes {
            if let item = itemNode.itemNode.item {
                for (message, _) in item.content {
                    if message.stableId == stableId {
                        itemNode.updateAfterCompletion = true
                    }
                }
            }
        }
    }

    func hasScheduledUpdateMessageAfterAnimationCompleted(stableId: UInt32) -> Bool {
        for itemNode in self.animatingItemNodes {
            if let item = itemNode.itemNode.item {
                for (message, _) in item.content {
                    if message.stableId == stableId {
                        return itemNode.updateAfterCompletion
                    }
                }
            }
        }
        return false
    }
}
