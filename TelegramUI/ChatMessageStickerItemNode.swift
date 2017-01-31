import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatMessageStickerItemNode: ChatMessageItemView {
    let imageNode: TransformImageNode
    var progressNode: RadialProgressNode?
    var tapRecognizer: UITapGestureRecognizer?
    
    var telegramFile: TelegramMediaFile?
    
    private let fetchDisposable = MetaDisposable()
    
    required init() {
        self.imageNode = TransformImageNode()
        
        super.init(layerBacked: false)
        
        self.imageNode.displaysAsynchronously = false
        self.addSubnode(self.imageNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    override func setupItem(_ item: ChatMessageItem) {
        super.setupItem(item)
        
        for media in item.message.media {
            if let telegramFile = media as? TelegramMediaFile {
                if self.telegramFile != telegramFile {
                    self.telegramFile = telegramFile
                    
                    let signal = chatMessageSticker(account: item.account, file: telegramFile, small: false)
                    self.imageNode.setSignal(account: item.account, signal: signal)
                    self.fetchDisposable.set(fileInteractiveFetched(account: item.account, file: telegramFile).start())
                }
                
                break
            }
        }
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let displaySize = CGSize(width: 200.0, height: 200.0)
        let telegramFile = self.telegramFile
        let layoutConstants = self.layoutConstants
        let imageLayout = self.imageNode.asyncLayout()
        
        return { item, width, mergedTop, mergedBottom, dateHeaderAtBottom in
            let incoming = item.message.effectivelyIncoming
            var imageSize: CGSize = CGSize(width: 100.0, height: 100.0)
            if let telegramFile = telegramFile {
                if let dimensions = telegramFile.dimensions {
                    imageSize = dimensions.aspectFitted(displaySize)
                } else if let thumbnailSize = telegramFile.previewRepresentations.first?.dimensions {
                    imageSize = thumbnailSize.aspectFitted(displaySize)
                }
            }
            
            let avatarInset: CGFloat = (item.peerId.isGroupOrChannel && item.message.author != nil) ? layoutConstants.avatarDiameter : 0.0
            
            var layoutInsets = UIEdgeInsets(top: mergedTop ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            let imageFrame = CGRect(origin: CGPoint(x: (incoming ? (layoutConstants.bubble.edgeInset + avatarInset) : (width - imageSize.width - layoutConstants.bubble.edgeInset)), y: 0.0), size: imageSize)
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageFrame.size, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets())
            
            let imageApply = imageLayout(arguments)
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: imageSize.height), insets: layoutInsets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.imageNode.frame = imageFrame
                    strongSelf.progressNode?.position = strongSelf.imageNode.position
                    imageApply()
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}
