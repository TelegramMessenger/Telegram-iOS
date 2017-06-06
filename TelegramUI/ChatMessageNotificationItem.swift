import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

public final class ChatMessageNotificationItem: NotificationItem {
    let account: Account
    let message: Message
    let tapAction: () -> Void
    
    public var groupingKey: AnyHashable? {
        return message.id.peerId
    }
    
    public init(account: Account, message: Message, tapAction: @escaping () -> Void) {
        self.account = account
        self.message = message
        self.tapAction = tapAction
    }
    
    public func node() -> NotificationItemNode {
        let node = ChatMessageNotificationItemNode()
        node.setupItem(self)
        return node
    }
    
    public func tapped() {
        self.tapAction()
    }
}

private let avatarFont: UIFont = UIFont(name: "ArialRoundedMTBold", size: 24.0)!

final class ChatMessageNotificationItemNode: NotificationItemNode {
    private var item: ChatMessageNotificationItem?
    
    private let avatarNode: AvatarNode
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private let imageNode: TransformImageNode
    
    override init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.maximumNumberOfLines = 1
        //self.titleNode.contentMode = .topLeft
        
        self.textNode = ASTextNode()
        self.textNode.isLayerBacked = true
        self.textNode.maximumNumberOfLines = 2
        //self.textNode.contentMode = .topLeft
        
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.imageNode)
    }
    
    func setupItem(_ item: ChatMessageNotificationItem) {
        self.item = item
        
        if let peer = messageMainPeer(item.message) {
            self.avatarNode.setPeer(account: item.account, peer: peer)
            
            if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle, font: Font.semibold(16.0), textColor: .black)
            } else if let author = item.message.author, author.id != peer.id {
                self.titleNode.attributedText = NSAttributedString(string: author.displayTitle + "@" + peer.displayTitle, font: Font.semibold(16.0), textColor: .black)
            } else {
                self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle, font: Font.semibold(16.0), textColor: .black)
            }
        }
        
        var updatedMedia: Media?
        var imageDimensions: CGSize?
        for media in item.message.media {
            if let image = media as? TelegramMediaImage {
                updatedMedia = image
                if let representation = largestRepresentationForPhoto(image) {
                    imageDimensions = representation.dimensions
                }
                break
            } else if let file = media as? TelegramMediaFile {
                updatedMedia = file
                if let representation = largestImageRepresentation(file.previewRepresentations) {
                    imageDimensions = representation.dimensions
                }
                break
            }
        }
        
        let imageNodeLayout = self.imageNode.asyncLayout()
        var applyImage: (() -> Void)?
        if let imageDimensions = imageDimensions {
            let boundingSize = CGSize(width: 55.0, height: 55.0)
            applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: 6.0), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
        }
        
        var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        if let updatedMedia = updatedMedia, imageDimensions != nil {
            if let image = updatedMedia as? TelegramMediaImage {
                updateImageSignal = mediaGridMessagePhoto(account: item.account, photo: image)
            } else if let file = updatedMedia as? TelegramMediaFile {
                if file.isSticker {
                    updateImageSignal = chatMessageSticker(account: item.account, file: file, small: true, fetched: true)
                } else if file.isVideo {
                    updateImageSignal = mediaGridMessageVideo(account: item.account, video: file)
                }
            }
        }
        
        var messageText = item.message.text
        for media in item.message.media {
            switch media {
                case _ as TelegramMediaImage:
                    if messageText.isEmpty {
                        messageText = "Photo"
                    }
                case let file as TelegramMediaFile:
                    var selectedText = false
                    loop: for attribute in file.attributes {
                        switch attribute {
                            case let .Audio(isVoice, _, title, performer, _):
                                if isVoice {
                                    messageText = "Voice Message"
                                } else {
                                    if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                                        messageText = title + " — " + performer
                                    } else if let title = title, !title.isEmpty {
                                        messageText = title
                                    } else if let performer = performer, !performer.isEmpty {
                                        messageText = performer
                                    } else {
                                        messageText = "Audio"
                                    }
                                }
                                selectedText = true
                                break loop
                            case let .Sticker(displayText, _):
                                messageText = "\(displayText) Sticker"
                                selectedText = true
                                break loop
                            case .Video:
                                if messageText.isEmpty {
                                    messageText = "Video"
                                }
                                selectedText = true
                                break loop
                            default:
                                break
                        }
                    }
                    if !selectedText {
                        messageText = file.fileName ?? "File"
                    }
                default:
                    break
            }
        }
        
        if let applyImage = applyImage {
            applyImage()
            self.imageNode.isHidden = false
        } else {
            self.imageNode.isHidden = true
        }
        
        if let updateImageSignal = updateImageSignal {
            self.imageNode.setSignal(account: item.account, signal: updateImageSignal)
        }
        
        self.textNode.attributedText = NSAttributedString(string: messageText, font: Font.regular(16.0), textColor: .black)
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let panelHeight: CGFloat = 74.0
        let leftInset: CGFloat = 77.0
        var rightInset: CGFloat = 8.0
        
        if !self.imageNode.isHidden {
            rightInset += 55.0 + 8.0
        }
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: 10.0, y: 10.0), size: CGSize(width: 54.0, height: 54.0)))
        
        let textSize = self.textNode.measure(CGSize(width: width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude))
        let textSpacing: CGFloat = -2.0
        
        let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: 1.0 + floor((panelHeight - textSize.height - 22.0) / 2.0)), size: CGSize(width: width - leftInset - rightInset, height: 22.0))
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + textSpacing), size: textSize))
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(x: width - 9.0 - 55.0, y: 9.0), size: CGSize(width: 55.0, height: 55.0)))
        
        return 74.0
    }
}
