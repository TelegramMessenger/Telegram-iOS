import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ContextUI

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

        case textInput(textInput: TextInput, replyPanel: ReplyAccessoryPanelNode?)
    }

    private final class AnimatingItemNode: ASDisplayNode {
        private let itemNode: ChatMessageItemView
        private let contextSourceNode: ContextExtractedContentContainingNode
        private let source: ChatMessageTransitionNode.Source

        private let scrollingContainer: ASDisplayNode
        private let containerNode: ASDisplayNode

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

                let duration: Double = 0.4
                let delay: Double = 0.0

                let transition: ContainedViewLayoutTransition = .animated(duration: duration * 0.8, curve: .spring)

                if let itemNode = self.itemNode as? ChatMessageBubbleItemNode {
                    itemNode.animateContentFromTextInputField(textInput: textInput, transition: transition)
                    if let sourceReplyPanel = sourceReplyPanel {
                        itemNode.animateReplyPanel(sourceReplyPanel: sourceReplyPanel, transition: transition)
                    }
                }

                self.containerNode.frame = targetAbsoluteRect.offsetBy(dx: -self.contextSourceNode.contentRect.minX, dy: self.contextSourceNode.contentRect.minY)
                self.contextSourceNode.updateAbsoluteRect?(self.containerNode.frame, UIScreen.main.bounds.size)
                self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: sourceAbsoluteRect.minY - targetAbsoluteRect.minY), to: CGPoint(), duration: duration, delay: delay, timingFunction: kCAMediaTimingFunctionSpring, additive: true, force: true, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.endAnimation()
                })
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), .spring, duration * 0.8)
                self.contextSourceNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: sourceAbsoluteRect.minY - targetAbsoluteRect.minY), .spring, duration)
                self.containerNode.layer.animatePosition(from: CGPoint(x: sourceAbsoluteRect.minX - targetAbsoluteRect.minX, y: 0.0), to: CGPoint(), duration: duration * 0.8, delay: delay, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
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
        if let itemNode = itemNode as? ChatMessageBubbleItemNode {
            let animatingItemNode = AnimatingItemNode(itemNode: itemNode, contextSourceNode: itemNode.mainContextSourceNode, source: source)
            self.animatingItemNodes.append(animatingItemNode)
            self.addSubnode(animatingItemNode)

            animatingItemNode.animationEnded = { [weak self, weak animatingItemNode] in
                guard let strongSelf = self, let animatingItemNode = animatingItemNode else {
                    return
                }
                animatingItemNode.removeFromSupernode()
                if let index = strongSelf.animatingItemNodes.firstIndex(where: { $0 === animatingItemNode }) {
                    strongSelf.animatingItemNodes.remove(at: index)
                }
            }

            animatingItemNode.frame = self.bounds
            animatingItemNode.beginAnimation()
        } else if let itemNode = itemNode as? ChatMessageStickerItemNode {

        } else if let itemNode = itemNode as? ChatMessageAnimatedStickerItemNode {

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
