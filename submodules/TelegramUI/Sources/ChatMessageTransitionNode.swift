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

        case textInput(textInput: TextInput, replyPanel: ReplyAccessoryPanelNode?)
        case stickerMediaInput(input: StickerInput, replyPanel: ReplyAccessoryPanelNode?)
        case audioMicInput(AudioMicInput)
        case videoMessage(VideoMessage)
        case mediaInput(MediaInput)
    }

    private final class AnimatingItemNode: ASDisplayNode {
        private let itemNode: ChatMessageItemView
        private let contextSourceNode: ContextExtractedContentContainingNode
        private let source: ChatMessageTransitionNode.Source
        private let getContentAreaInScreenSpace: () -> CGRect

        private let scrollingContainer: ASDisplayNode
        private let containerNode: ASDisplayNode
        private let clippingNode: ASDisplayNode

        weak var overlayController: OverlayTransitionContainerController?

        var animationEnded: (() -> Void)?

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
            let verticalDuration: Double = 0.5
            let horizontalDuration: Double = verticalDuration * 0.5
            let delay: Double = 0.0

            var updatedContentAreaInScreenSpace = self.getContentAreaInScreenSpace()
            updatedContentAreaInScreenSpace.origin.x = 0.0
            updatedContentAreaInScreenSpace.size.width = self.clippingNode.bounds.width

            //let timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0)

            let clippingOffset = updatedContentAreaInScreenSpace.minY - self.clippingNode.frame.minY
            self.clippingNode.frame = CGRect(origin: CGPoint(x: 0.0, y: updatedContentAreaInScreenSpace.minY), size: self.clippingNode.bounds.size)
            self.clippingNode.bounds = CGRect(origin: CGPoint(x: 0.0, y: clippingOffset), size: self.clippingNode.bounds.size)

            //self.clippingNode.layer.animateFrame(from: self.clippingNode.frame, to: updatedContentAreaInScreenSpace, duration: verticalDuration, mediaTimingFunction: timingFunction, removeOnCompletion: false)
            //self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: updatedContentAreaInScreenSpace.minY, duration: verticalDuration, mediaTimingFunction: timingFunction, removeOnCompletion: false)

            switch self.source {
            case let .textInput(initialTextInput, replyPanel):
                self.contextSourceNode.isExtractedToContextPreview = true
                self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: nil)
                let sourceBackgroundAbsoluteRect = initialTextInput.backgroundView.frame.offsetBy(dx: initialTextInput.sourceRect.minX, dy: initialTextInput.sourceRect.minY)
                let sourceAbsoluteRect = CGRect(origin: CGPoint(x: sourceBackgroundAbsoluteRect.minX, y: sourceBackgroundAbsoluteRect.maxY - self.contextSourceNode.contentRect.height), size: self.contextSourceNode.contentRect.size)

                let textInput = ChatMessageTransitionNode.Source.TextInput(backgroundView: initialTextInput.backgroundView, contentView: initialTextInput.contentView, sourceRect: initialTextInput.sourceRect)

                textInput.backgroundView.frame = CGRect(origin: CGPoint(x: 0.0, y: sourceAbsoluteRect.height - sourceBackgroundAbsoluteRect.height), size: textInput.backgroundView.bounds.size)
                textInput.contentView.frame = textInput.contentView.frame.offsetBy(dx: 0.0, dy: sourceAbsoluteRect.height - sourceBackgroundAbsoluteRect.height)

                var sourceReplyPanel: ReplyPanel?
                if let replyPanel = replyPanel, let replyPanelParentView = replyPanel.view.superview {
                    var replySourceAbsoluteFrame = replyPanelParentView.convert(replyPanel.originalFrameBeforeDismissed ?? replyPanel.frame, to: nil)
                    replySourceAbsoluteFrame.origin.x -= sourceAbsoluteRect.minX - self.contextSourceNode.contentRect.minX
                    replySourceAbsoluteFrame.origin.y -= sourceAbsoluteRect.minY - self.contextSourceNode.contentRect.minY

                    sourceReplyPanel = ReplyPanel(titleNode: replyPanel.titleNode, textNode: replyPanel.textNode, lineNode: replyPanel.lineNode, imageNode: replyPanel.imageNode, relativeSourceRect: replySourceAbsoluteFrame)
                }

                self.itemNode.cancelInsertionAnimations()

                let transition: ContainedViewLayoutTransition = .animated(duration: horizontalDuration, curve: .custom(0.33, 0.0, 0.0, 1.0))
                let verticalTransition: ContainedViewLayoutTransition = .animated(duration: verticalDuration, curve: .custom(0.33, 0.0, 0.0, 1.0))

                if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                    itemNode.animateContentFromTextInputField(textInput: textInput, horizontalTransition: transition, verticalTransition: verticalTransition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, horizontalTransition: transition, verticalTransition: verticalTransition)
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
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.maxY - targetAbsoluteRect.maxY), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true, force: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.endAnimation()
                })
                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true)
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), .custom(0.33, 0.0, 0.0, 1.0), horizontalDuration)
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: sourceAbsoluteRect.maxY - targetAbsoluteRect.maxY), .custom(0.33, 0.0, 0.0, 1.0), verticalDuration)
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
            case let .videoMessage(videoMessage):
                let transition: ContainedViewLayoutTransition = .animated(duration: verticalDuration, curve: .custom(0.33, 0.0, 0.0, 1.0))

                if let itemNode = self.itemNode as? ChatMessageInstantVideoItemNode {
                    itemNode.cancelInsertionAnimations()

                    self.contextSourceNode.isExtractedToContextPreview = true
                    self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                    self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                    let sourceAbsoluteRect = videoMessage.view.frame
                    let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: nil)

                    videoMessage.view.frame = videoMessage.view.frame.offsetBy(dx: targetAbsoluteRect.midX - sourceAbsoluteRect.midX, dy: targetAbsoluteRect.midY - sourceAbsoluteRect.midY)

                    self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)
                    self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true, force: true)

                    self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true, completion: { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }

                        strongSelf.endAnimation()
                    })

                    itemNode.animateFromSnapshot(snapshotView: videoMessage.view, transition: transition)
                }
            case let .mediaInput(mediaInput):
                if let snapshotView = mediaInput.extractSnapshot() {
                    if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                        itemNode.cancelInsertionAnimations()

                        self.contextSourceNode.isExtractedToContextPreview = true
                        self.contextSourceNode.isExtractedToContextPreviewUpdated?(true)

                        self.containerNode.addSubnode(self.contextSourceNode.contentNode)

                        let targetAbsoluteRect = self.contextSourceNode.view.convert(self.contextSourceNode.contentRect, to: nil)
                        let sourceBackgroundAbsoluteRect = snapshotView.frame
                        let sourceAbsoluteRect = CGRect(origin: CGPoint(x: sourceBackgroundAbsoluteRect.midX - self.contextSourceNode.contentRect.size.width / 2.0, y: sourceBackgroundAbsoluteRect.midY - self.contextSourceNode.contentRect.size.height / 2.0), size: self.contextSourceNode.contentRect.size)

                        let transition: ContainedViewLayoutTransition = .animated(duration: verticalDuration, curve: .custom(0.33, 0.0, 0.0, 1.0))
                        let verticalTransition: ContainedViewLayoutTransition = .animated(duration: horizontalDuration, curve: .custom(0.33, 0.0, 0.0, 1.0))

                        if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                            itemNode.animateContentFromMediaInput(snapshotView: snapshotView, horizontalTransition: verticalTransition, verticalTransition: transition)
                        }

                        self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: -self.contextSourceNode.contentRect.minY)

                        snapshotView.center = targetAbsoluteRect.center.offsetBy(dx: -self.containerNode.frame.minX, dy: -self.containerNode.frame.minY)
                        self.containerNode.view.addSubview(snapshotView)

                        self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)

                        self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.midY - targetAbsoluteRect.midY), to: CGPoint(), duration: horizontalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true, force: true)
                        self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.midX - targetAbsoluteRect.midX, y: 0.0), to: CGPoint(), duration: verticalDuration, delay: delay, mediaTimingFunction: CAMediaTimingFunction(controlPoints: 0.33, 0.0, 0.0, 1.0), additive: true, force: true, completion: { [weak self] _ in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.endAnimation()
                        })

                        verticalTransition.animateTransformScale(node: self.contextSourceNode.contentNode, from: CGPoint(x: sourceBackgroundAbsoluteRect.width / targetAbsoluteRect.width, y: sourceBackgroundAbsoluteRect.height / targetAbsoluteRect.height))

                        verticalTransition.updateTransformScale(layer: snapshotView.layer, scale: CGPoint(x: 1.0 / (sourceBackgroundAbsoluteRect.width / targetAbsoluteRect.width), y: 1.0 / (sourceBackgroundAbsoluteRect.height / targetAbsoluteRect.height)))

                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })

                        self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), .custom(0.33, 0.0, 0.0, 1.0), horizontalDuration)
                        self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: sourceAbsoluteRect.maxY - targetAbsoluteRect.maxY), .custom(0.33, 0.0, 0.0, 1.0), verticalDuration)
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

    private let listNode: ChatHistoryListNode
    private let getContentAreaInScreenSpace: () -> CGRect
    private let onTransitionEvent: (ContainedViewLayoutTransition) -> Void

    private var currentPendingItem: (Int64, Source, () -> Void)?

    private var animatingItemNodes: [AnimatingItemNode] = []

    var hasScheduledTransitions: Bool {
        return self.currentPendingItem != nil
    }

    init(listNode: ChatHistoryListNode, getContentAreaInScreenSpace: @escaping () -> CGRect, onTransitionEvent: @escaping (ContainedViewLayoutTransition) -> Void) {
        self.listNode = listNode
        self.getContentAreaInScreenSpace = getContentAreaInScreenSpace
        self.onTransitionEvent = onTransitionEvent

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
        } else if let itemNode = itemNode as? ChatMessageInstantVideoItemNode {
            contextSourceNode = itemNode.contextSourceNode
        }

        if let contextSourceNode = contextSourceNode {
            let animatingItemNode = AnimatingItemNode(itemNode: itemNode, contextSourceNode: contextSourceNode, source: source, getContentAreaInScreenSpace: self.getContentAreaInScreenSpace)
            animatingItemNode.updateLayout(size: self.bounds.size)
            
            self.animatingItemNodes.append(animatingItemNode)
            switch source {
            case .audioMicInput, .videoMessage, .mediaInput:
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
            }

            animatingItemNode.frame = self.bounds
            animatingItemNode.beginAnimation()

            self.onTransitionEvent(.animated(duration: 0.5, curve: .custom(0.33, 0.0, 0.0, 1.0)))
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

    func addContentOffset(offset: CGFloat, itemNode: ListViewItemNode?) {
        for animatingItemNode in self.animatingItemNodes {
            animatingItemNode.addContentOffset(offset: offset, itemNode: itemNode)
        }
    }
}
