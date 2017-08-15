import Foundation
import AsyncDisplayKit
import Postbox
import Display
import TelegramCore
import SwiftSignalKit

private let titleFont: UIFont = {
    if #available(iOS 8.2, *) {
        return UIFont.systemFont(ofSize: 14.0, weight: UIFontWeightMedium)
    } else {
        return CTFontCreateWithName("HelveticaNeue-Medium" as CFString?, 14.0, nil)
    }
}()
private let textFont = Font.regular(14.0)

func textStringForReplyMessage(_ message: Message) -> (String, Bool) {
    if !message.text.isEmpty {
        return (message.text, false)
    } else {
        for media in message.media {
            switch media {
                case _ as TelegramMediaImage:
                    return ("Photo", true)
                case let file as TelegramMediaFile:
                    var fileName: String = "File"
                    for attribute in file.attributes {
                        switch attribute {
                            case let .Sticker(text, _, _):
                                return ("\(text) Sticker", true)
                            case let .FileName(name):
                                fileName = name
                            case let .Audio(isVoice, _, title, performer, _):
                                if isVoice {
                                    return ("Voice Message", true)
                                } else {
                                    if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                                        return (title + " — " + performer, true)
                                    } else if let title = title, !title.isEmpty {
                                        return (title, true)
                                    } else if let performer = performer, !performer.isEmpty {
                                        return (performer, true)
                                    } else {
                                        return ("Audio", true)
                                    }
                                }
                            case .Video:
                                if file.isAnimated {
                                    return ("GIF", true)
                                } else {
                                    return ("Video", true)
                                }
                            default:
                                break
                        }
                    }
                    return (fileName, true)
                case _ as TelegramMediaContact:
                    return ("Contact", true)
                case let game as TelegramMediaGame:
                    return (game.title, true)
                case _ as TelegramMediaMap:
                    return ("Map", true)
                case let action as TelegramMediaAction:
                    return ("", true)
                default:
                    break
            }
        }
        return ("", false)
    }
}

enum ChatMessageReplyInfoType {
    case bubble(incoming: Bool)
    case standalone
}

class ChatMessageReplyInfoNode: ASDisplayNode {
    private let contentNode: ASDisplayNode
    private let lineNode: ASDisplayNode
    private var titleNode: TextNode?
    private var textNode: TextNode?
    private var imageNode: TransformImageNode?
    private var previousMedia: Media?
    
    override init() {
        self.contentNode = ASDisplayNode()
        self.contentNode.displaysAsynchronously = true
        self.contentNode.isLayerBacked = true
        self.contentNode.contentMode = .left
        self.contentNode.contentsScale = UIScreenScale
        
        self.lineNode = ASDisplayNode()
        self.lineNode.displaysAsynchronously = false
        self.lineNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.lineNode)
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageReplyInfoNode?) -> (_ theme: PresentationTheme, _ account: Account, _ type: ChatMessageReplyInfoType, _ message: Message, _ constrainedSize: CGSize) -> (CGSize, () -> ChatMessageReplyInfoNode) {
        
        let titleNodeLayout = TextNode.asyncLayout(maybeNode?.titleNode)
        let textNodeLayout = TextNode.asyncLayout(maybeNode?.textNode)
        let imageNodeLayout = TransformImageNode.asyncLayout(maybeNode?.imageNode)
        let previousMedia = maybeNode?.previousMedia
        
        return { theme, account, type, message, constrainedSize in
            let titleString = message.author?.displayTitle ?? ""
            let (textString, textMedia) = textStringForReplyMessage(message)
            
            let titleColor: UIColor
            let lineColor: UIColor
            let textColor: UIColor
                
            switch type {
                case let .bubble(incoming):
                    titleColor = incoming ? theme.chat.bubble.incomingAccentColor : theme.chat.bubble.outgoingAccentColor
                    lineColor = incoming ? theme.chat.bubble.incomingAccentColor : theme.chat.bubble.outgoingAccentColor
                    textColor = incoming ? theme.chat.bubble.incomingPrimaryTextColor : theme.chat.bubble.outgoingPrimaryTextColor
                case .standalone:
                    titleColor = theme.chat.serviceMessage.serviceMessagePrimaryTextColor
                    lineColor = titleColor
                    textColor = titleColor
            }
            
            var leftInset: CGFloat = 10.0
            
            var updatedMedia: Media?
            var imageDimensions: CGSize?
            for media in message.media {
                if let image = media as? TelegramMediaImage {
                    updatedMedia = image
                    if let representation = largestRepresentationForPhoto(image) {
                        imageDimensions = representation.dimensions
                    }
                    break
                } else if let file = media as? TelegramMediaFile {
                    updatedMedia = file
                    if let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                        imageDimensions = representation.dimensions
                    }
                    break
                }
            }
            
            var applyImage: (() -> TransformImageNode)?
            if let imageDimensions = imageDimensions {
                leftInset += 36.0
                let boundingSize = CGSize(width: 30.0, height: 30.0)
                applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: 2.0), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
            }
            
            var mediaUpdated = false
            if let updatedMedia = updatedMedia, let previousMedia = previousMedia {
                mediaUpdated = !updatedMedia.isEqual(previousMedia)
            } else if (updatedMedia != nil) != (previousMedia != nil) {
                mediaUpdated = true
            }
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if let updatedMedia = updatedMedia, mediaUpdated && imageDimensions != nil {
                if let image = updatedMedia as? TelegramMediaImage {
                    updateImageSignal = chatMessagePhotoThumbnail(account: account, photo: image)
                } else if let file = updatedMedia as? TelegramMediaFile {
                    
                }
            }
            
            let maximumTextWidth = max(0.0, constrainedSize.width - leftInset)
            
            let contrainedTextSize = CGSize(width: maximumTextWidth, height: constrainedSize.height)
            
            let (titleLayout, titleApply) = titleNodeLayout(NSAttributedString(string: titleString, font: titleFont, textColor: titleColor), nil, 1, .end, contrainedTextSize, .natural, nil, UIEdgeInsets())
            let (textLayout, textApply) = textNodeLayout(NSAttributedString(string: textString, font: textFont, textColor: textMedia ? titleColor : textColor), nil, 1, .end, contrainedTextSize, .natural, nil, UIEdgeInsets())
            
            let size = CGSize(width: max(titleLayout.size.width, textLayout.size.width) + leftInset, height: titleLayout.size.height + textLayout.size.height)
            
            return (size, {
                let node: ChatMessageReplyInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageReplyInfoNode()
                }
                
                node.previousMedia = updatedMedia
                
                let titleNode = titleApply()
                let textNode = textApply()
                
                if node.titleNode == nil {
                    titleNode.isLayerBacked = true
                    node.titleNode = titleNode
                    node.contentNode.addSubnode(titleNode)
                }
                
                if node.textNode == nil {
                    textNode.isLayerBacked = true
                    node.textNode = textNode
                    node.contentNode.addSubnode(textNode)
                }
                
                if let applyImage = applyImage {
                    let imageNode = applyImage()
                    if node.imageNode == nil {
                        imageNode.isLayerBacked = true
                        node.addSubnode(imageNode)
                        node.imageNode = imageNode
                    }
                    imageNode.frame = CGRect(origin: CGPoint(x: 8.0, y: 3.0), size: CGSize(width: 30.0, height: 30.0))
                    
                    if let updateImageSignal = updateImageSignal {
                        imageNode.setSignal(account: account, signal: updateImageSignal)
                    }
                } else if let imageNode = node.imageNode {
                    imageNode.removeFromSupernode()
                    node.imageNode = nil
                }
                
                titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: titleLayout.size)
                textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: titleLayout.size.height), size: textLayout.size)
                
                node.lineNode.backgroundColor = lineColor
                node.lineNode.frame = CGRect(origin: CGPoint(x: 1.0, y: 3.0), size: CGSize(width: 2.0, height: size.height - 4.0))
                
                node.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                
                return node
            })
        }
    }
}
