import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import AccountContext
import ChatSendMessageActionUI
import SwiftSignalKit
import ComponentFlow
import Display
import Postbox
import TelegramCore
import WallpaperBackgroundNode
import AudioWaveform
import ChatMessageItemView

public final class ChatSendAudioMessageContextPreview: UIView, ChatSendMessageContextScreenMediaPreview {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let wallpaperBackgroundNode: WallpaperBackgroundNode?
    private let waveform: AudioWaveform
    
    private var messageNodes: [ListViewItemNode]?
    private let messagesContainer: UIView
    
    public var isReady: Signal<Bool, NoError> {
        return .single(true)
    }

    public var view: UIView {
        return self
    }
    
    public var globalClippingRect: CGRect? {
        return nil
    }

    public var layoutType: ChatSendMessageContextScreenMediaPreviewLayoutType {
        return .message
    }
    
    public init(context: AccountContext, presentationData: PresentationData, wallpaperBackgroundNode: WallpaperBackgroundNode?, waveform: AudioWaveform) {
        self.context = context
        self.presentationData = presentationData
        self.wallpaperBackgroundNode = wallpaperBackgroundNode
        self.waveform = waveform
        
        self.messagesContainer = UIView()
        self.messagesContainer.layer.sublayerTransform = CATransform3DMakeScale(-1.0, -1.0, 1.0)
        
        super.init(frame: CGRect())
        
        self.addSubview(self.messagesContainer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public func animateIn(transition: Transition) {
        transition.animateAlpha(view: self.messagesContainer, from: 0.0, to: 1.0)
        transition.animateScale(view: self.messagesContainer, from: 0.001, to: 1.0)
    }

    public func animateOut(transition: Transition) {
        transition.setAlpha(view: self.messagesContainer, alpha: 0.0)
        transition.setScale(view: self.messagesContainer, scale: 0.001)
    }

    public func animateOutOnSend(transition: Transition) {
        transition.setAlpha(view: self.messagesContainer, alpha: 0.0)
    }

    public func update(containerSize: CGSize, transition: Transition) -> CGSize {
        let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 23, title: nil, performer: nil, waveform: self.waveform.makeBitstream())]
        let voiceMedia = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: voiceAttributes)
        
        let message = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: self.context.account.peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [voiceMedia], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        
        let item = self.context.sharedContext.makeChatMessagePreviewItem(
            context: self.context,
            messages: [message],
            theme: presentationData.theme,
            strings: presentationData.strings,
            wallpaper: presentationData.chatWallpaper,
            fontSize: presentationData.chatFontSize,
            chatBubbleCorners: presentationData.chatBubbleCorners,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameOrder: presentationData.nameDisplayOrder,
            forcedResourceStatus: FileMediaResourceStatus(mediaStatus: .fetchStatus(.Local), fetchStatus: .Local),
            tapMessage: nil,
            clickThroughMessage: nil,
            backgroundNode: self.wallpaperBackgroundNode,
            availableReactions: nil,
            accountPeer: nil,
            isCentered: false,
            isPreview: true,
            isStandalone: true
        )
        let items = [item]
        
        let params = ListViewItemLayoutParams(width: containerSize.width, leftInset: 0.0, rightInset: 0.0, availableHeight: containerSize.height)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                let itemNode = messageNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: containerSize.width, height: layout.size.height))
                    
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = nodeFrame
                    itemNode.isUserInteractionEnabled = false
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.isUserInteractionEnabled = false
                messageNodes.append(itemNode!)
                self.messagesContainer.addSubview(itemNode!.view)
            }
            self.messageNodes = messageNodes
        }
        
        guard let messageNode = self.messageNodes?.first as? ChatMessageItemView else {
            return CGSize(width: 10.0, height: 10.0)
        }
        let contentFrame = messageNode.contentFrame()
        
        self.messagesContainer.frame = CGRect(origin: CGPoint(x: 6.0, y: 3.0), size: CGSize(width: contentFrame.width, height: contentFrame.height))
        
        return CGSize(width: contentFrame.width - 4.0, height: contentFrame.height + 2.0)
    }
}
