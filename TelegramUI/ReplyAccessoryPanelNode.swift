import Foundation
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

private let lineImage = generateVerticallyStretchableFilledCircleImage(radius: 1.0, color: UIColor(0x007ee5))
private let closeButtonImage = generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setStrokeColor(UIColor(0x9099A2).cgColor)
    context.setLineWidth(2.0)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 1.0, y: 1.0))
    context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
    context.strokePath()
    context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
    context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
    context.strokePath()
})

final class ReplyAccessoryPanelNode: AccessoryPanelNode {
    private let messageDisposable = MetaDisposable()
    let messageId: MessageId
    
    private var previousMedia: Media?
    
    let closeButton: ASButtonNode
    let lineNode: ASImageNode
    let titleNode: ASTextNode
    let textNode: ASTextNode
    let imageNode: TransformImageNode
    
    init(account: Account, messageId: MessageId) {
        self.messageId = messageId
        
        self.closeButton = ASButtonNode()
        self.closeButton.setImage(closeButtonImage, for: [])
        self.closeButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.displaysAsynchronously = false
        self.lineNode.image = lineImage
        
        self.titleNode = ASTextNode()
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = ASTextNode()
        self.textNode.truncationMode = .byTruncatingTail
        self.textNode.maximumNumberOfLines = 1
        self.textNode.displaysAsynchronously = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.isHidden = true
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.imageNode)
        
        self.messageDisposable.set((account.postbox.messageAtId(messageId)
            |> deliverOnMainQueue).start(next: { [weak self] message in
            if let strongSelf = self {
                var authorName = ""
                var text = ""
                if let author = message?.author {
                    authorName = author.displayTitle
                }
                if let message = message {
                    let (string, _) = textStringForReplyMessage(message)
                    text = string
                }
                
                var updatedMedia: Media?
                var imageDimensions: CGSize?
                if let message = message {
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
                }
                
                let imageNodeLayout = strongSelf.imageNode.asyncLayout()
                var applyImage: (() -> Void)?
                if let imageDimensions = imageDimensions {
                    let boundingSize = CGSize(width: 35.0, height: 35.0)
                    applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: 2.0), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                }
                
                var mediaUpdated = false
                if let updatedMedia = updatedMedia, let previousMedia = strongSelf.previousMedia {
                    mediaUpdated = !updatedMedia.isEqual(previousMedia)
                } else if (updatedMedia != nil) != (strongSelf.previousMedia != nil) {
                    mediaUpdated = true
                }
                
                var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                if mediaUpdated {
                    if let updatedMedia = updatedMedia, imageDimensions != nil {
                        if let image = updatedMedia as? TelegramMediaImage {
                            updateImageSignal = chatMessagePhotoThumbnail(account: account, photo: image)
                        } else if let file = updatedMedia as? TelegramMediaFile {
                            
                        }
                    } else {
                        updateImageSignal = .single({ _ in return nil })
                    }
                }
                
                strongSelf.titleNode.attributedText = NSAttributedString(string: authorName, font: Font.medium(15.0), textColor: UIColor(0x007ee5))
                strongSelf.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: UIColor.black)
                
                if let applyImage = applyImage {
                    applyImage()
                    strongSelf.imageNode.isHidden = false
                } else {
                    strongSelf.imageNode.isHidden = true
                }
                
                if let updateImageSignal = updateImageSignal {
                    strongSelf.imageNode.setSignal(account: account, signal: updateImageSignal)
                }
                
                strongSelf.setNeedsLayout()
            }
        }))
    }
    
    deinit {
        self.messageDisposable.dispose()
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let leftInset: CGFloat = 55.0
        let textLineInset: CGFloat = 10.0
        let rightInset: CGFloat = 55.0
        let textRightInset: CGFloat = 20.0
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        self.closeButton.frame = CGRect(origin: CGPoint(x: bounds.size.width - rightInset - closeButtonSize.width, y: 19.0), size: closeButtonSize)
        
        self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))
        
        var imageTextInset: CGFloat = 0.0
        if !self.imageNode.isHidden {
            imageTextInset = 9.0 + 35.0
        }
        self.imageNode.frame = CGRect(origin: CGPoint(x: leftInset + 9.0, y: 8.0), size: CGSize(width: 35.0, height: 35.0))
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset, y: 7.0), size: titleSize)
        
        let textSize = self.textNode.measure(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset, y: 25.0), size: textSize)
    }
    
    @objc func closePressed() {
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
}
