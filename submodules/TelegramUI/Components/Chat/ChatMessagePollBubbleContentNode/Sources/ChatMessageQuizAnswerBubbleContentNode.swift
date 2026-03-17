import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatMessageAttachedContentNode
import ChatControllerInteraction
import ComposePollScreen
import AccountContext

public final class ChatMessageQuizAnswerBubbleContentNode: ChatMessageBubbleContentNode {
    private let contentNode: ChatMessageAttachedContentNode
    
    private let temporaryHiddenMediaDisposable = MetaDisposable()
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            self.contentNode.visibility = visibility
        }
    }
    
    required public init() {
        self.contentNode = ChatMessageAttachedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.temporaryHiddenMediaDisposable.dispose()
    }
    
    func openSolutionMedia() {
        guard let item = self.item, let poll = item.message.media.first(where: { $0 is TelegramMediaPoll }) as? TelegramMediaPoll, let solution = poll.results.solution, let media = poll.results.solution?.media else {
            return
        }
        var attributes = item.message.attributes
        attributes.removeAll(where: { $0 is TextEntitiesMessageAttribute })
        if !solution.entities.isEmpty {
            attributes.append(TextEntitiesMessageAttribute(entities: solution.entities))
        }
        
        let message = item.message.withUpdatedText(solution.text).withUpdatedAttributes(attributes).withUpdatedMedia([media])
        let _ = item.context.sharedContext.openChatMessage(OpenChatMessageParams(
            context: item.context,
            updatedPresentationData: item.controllerInteraction.updatedPresentationData,
            chatLocation: item.chatLocation,
            chatFilterTag: nil,
            chatLocationContextHolder: nil,
            message: message,
            mediaIndex: 0,
            standalone: true,
            reverseMessageGalleryOrder: false,
            navigationController: item.controllerInteraction.navigationController(),
            dismissInput: {
                item.controllerInteraction.dismissTextInput()
            },
            present: { controller, arguments, presentationContextType in
                switch presentationContextType {
                case .current:
                    item.controllerInteraction.presentControllerInCurrent(controller, arguments)
                default:
                    item.controllerInteraction.presentController(controller, arguments)
                }
            },
            transitionNode: { [weak self] messageId, media, adjustRect in
                guard let self else {
                    return nil
                }
                return self.transitionNode(messageId: messageId, media: media, adjustRect: adjustRect)
            },
            addToTransitionSurface: { [weak self] view in
                guard let self else {
                    return
                }
                if let superview = self.itemNode?.view.superview?.superview?.superview {
                    superview.addSubview(view)
                } else {
                    self.view.addSubview(view)
                }
            },
            openUrl: { url in
                item.controllerInteraction.openUrl(.init(url: url, concealed: false, progress: Promise()))
            },
            openPeer: { peer, navigation in
                item.controllerInteraction.openPeer(EnginePeer(peer), navigation, nil, .default)
            },
            callPeer: { peerId, isVideo in
                item.controllerInteraction.callPeer(peerId, isVideo)
            },
            openConferenceCall: { message in
                item.controllerInteraction.openConferenceCall(message)
            },
            enqueueMessage: { _ in
            },
            sendSticker: { fileReference, sourceNode, sourceRect in
                item.controllerInteraction.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect, nil, [])
            },
            sendEmoji: { text, attribute in
                item.controllerInteraction.sendEmoji(text, attribute, false)
            },
            setupTemporaryHiddenMedia: { [weak self] signal, _, galleryMedia in
                guard let self else {
                    return
                }
                self.temporaryHiddenMediaDisposable.set((signal |> deliverOnMainQueue).startStrict(next: { [weak self] entry in
                    guard let self, let item = self.item else {
                        return
                    }
                    var hiddenMedia = item.controllerInteraction.hiddenMedia
                    if entry != nil {
                        hiddenMedia[item.message.id] = [galleryMedia]
                    } else {
                        hiddenMedia.removeValue(forKey: item.message.id)
                    }
                    item.controllerInteraction.hiddenMedia = hiddenMedia
                    self.itemNode?.updateHiddenMedia()
                }))
            },
            chatAvatarHiddenMedia: { _, _ in
            },
            gallerySource: .standaloneMessage(message, 0)
        ))
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let contentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, _, constrainedSize, _ in
            //TODO:localize
            let title: String = "Explanation"
            var text: String = ""
            var entities: [MessageTextEntity] = []
            var mediaAndFlags: ([Media], ChatMessageAttachedContentNodeMediaFlags)? = nil
            if let poll = item.message.media.first(where: { $0 is TelegramMediaPoll }) as? TelegramMediaPoll, let solution = poll.results.solution {
                text = solution.text
                entities = solution.entities
                mediaAndFlags = solution.media.flatMap { ([$0], []) }
            }
    
            let (initialWidth, continueLayout) = contentNodeLayout(item.presentationData, item.controllerInteraction.automaticMediaDownloadSettings, item.associatedData, item.attributes, item.context, item.controllerInteraction, item.message, true, .peer(id: item.message.id.peerId), title, nil, nil, text, entities, mediaAndFlags, nil, nil, nil, true, layoutConstants, preparePosition, constrainedSize, item.controllerInteraction.presentationContext.animationCache, item.controllerInteraction.presentationContext.animationRenderer)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, initialWidth, { constrainedSize, position in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize, position)
                
                return (refinedWidth, { boundingWidth in
                    let (size, apply) = finalizeLayout(boundingWidth)
                    
                    return (size, { [weak self] animation, synchronousLoads, applyInfo in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            apply(animation, synchronousLoads, applyInfo)
                            
                            strongSelf.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                            
                            strongSelf.contentNode.openMedia = { [weak self] _ in
                                self?.openSolutionMedia()
                            }
                        }
                    })
                })
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.bounds.contains(point) {
            let contentNodeFrame = self.contentNode.frame
            return self.contentNode.tapActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY), gesture: gesture, isEstimating: isEstimating)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    override public func updateTouchesAtPoint(_ point: CGPoint?) {
        let contentNodeFrame = self.contentNode.frame
        self.contentNode.updateTouchesAtPoint(point.flatMap { $0.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY) })
    }
    
    override public func updateHiddenMedia(_ media: [Media]?) -> Bool {
        return self.contentNode.updateHiddenMedia(media)
    }
    
    override public func transitionNode(messageId: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.item?.message.id != messageId {
            return nil
        }
        return self.contentNode.transitionNode(media: media)
    }
}

