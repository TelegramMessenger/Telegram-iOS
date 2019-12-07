import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import StickerResources
import PhotoResources
import TelegramStringFormatting

final class ChatPinnedMessageTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    private let tapButton: HighlightTrackingButtonNode
    private let closeButton: HighlightableButtonNode
    private let lineNode: ASImageNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private let imageNode: TransformImageNode
    
    private let separatorNode: ASDisplayNode

    private var currentLayout: (CGFloat, CGFloat, CGFloat)?
    private var currentMessage: Message?
    private var previousMediaReference: AnyMediaReference?
    
    private let fetchDisposable = MetaDisposable()

    private let queue = Queue()
    
    init(context: AccountContext) {
        self.context = context
        
        self.tapButton = HighlightTrackingButtonNode()
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.displaysAsynchronously = false
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = true
        self.titleNode.isUserInteractionEnabled = false
        
        self.textNode = TextNode()
        self.textNode.displaysAsynchronously = true
        self.textNode.isUserInteractionEnabled = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.imageNode.isHidden = true
        
        super.init()
        
        self.tapButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                    strongSelf.lineNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.lineNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.lineNode.alpha = 1.0
                    strongSelf.lineNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.imageNode)
        
        self.tapButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        self.addSubnode(self.tapButton)
        
        self.addSubnode(self.separatorNode)
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    private var theme: PresentationTheme?
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        let panelHeight: CGFloat = 50.0
        var themeUpdated = false
        
        if self.theme !== interfaceState.theme {
            themeUpdated = true
            self.theme = interfaceState.theme
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(interfaceState.theme), for: [])
            self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(interfaceState.theme)
            self.backgroundColor = interfaceState.theme.chat.historyNavigation.fillColor
            self.separatorNode.backgroundColor = interfaceState.theme.chat.historyNavigation.strokeColor
        }
        
        var messageUpdated = false
        if let currentMessage = self.currentMessage, let pinnedMessage = interfaceState.pinnedMessage {
            if currentMessage.id != pinnedMessage.id || currentMessage.stableVersion != pinnedMessage.stableVersion {
                messageUpdated = true
            }
        } else if (self.currentMessage != nil) != (interfaceState.pinnedMessage != nil) {
            messageUpdated = true
        }
        
        if messageUpdated || themeUpdated {
            let previousMessageWasNil = self.currentMessage == nil
            self.currentMessage = interfaceState.pinnedMessage
            
            if let currentMessage = currentMessage, let currentLayout = self.currentLayout {
                self.enqueueTransition(width: currentLayout.0, leftInset: currentLayout.1, rightInset: currentLayout.2, transition: .immediate, message: currentMessage, theme: interfaceState.theme, strings: interfaceState.strings, nameDisplayOrder: interfaceState.nameDisplayOrder, accountPeerId: self.context.account.peerId, firstTime: previousMessageWasNil)
            }
        }
        
        let contentLeftInset: CGFloat = 10.0 + leftInset
        let rightInset: CGFloat = 18.0 + rightInset
        
        transition.updateFrame(node: self.lineNode, frame: CGRect(origin: CGPoint(x: contentLeftInset, y: 7.0), size: CGSize(width: 2.0, height: panelHeight - 14.0)))
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: width - rightInset - closeButtonSize.width, y: 19.0), size: closeButtonSize))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        self.tapButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: width - rightInset - closeButtonSize.width - 4.0, height: panelHeight))
        
        if self.currentLayout?.0 != width || self.currentLayout?.1 != leftInset || self.currentLayout?.2 != rightInset {
            self.currentLayout = (width, leftInset, rightInset)
            
            if let currentMessage = self.currentMessage {
                self.enqueueTransition(width: width, leftInset: leftInset, rightInset: rightInset, transition: .immediate, message: currentMessage, theme: interfaceState.theme, strings: interfaceState.strings, nameDisplayOrder: interfaceState.nameDisplayOrder, accountPeerId: interfaceState.accountPeerId, firstTime: true)
            }
        }
        
        return panelHeight
    }
    
    private func enqueueTransition(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, message: Message, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, accountPeerId: PeerId, firstTime: Bool) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let imageNodeLayout = self.imageNode.asyncLayout()
        
        let previousMediaReference = self.previousMediaReference
        let context = self.context
        
        let targetQueue: Queue
        if firstTime {
            targetQueue = Queue.mainQueue()
        } else {
            targetQueue = self.queue
        }
        
        targetQueue.async { [weak self] in
            let contentLeftInset: CGFloat = leftInset + 10.0
            var textLineInset: CGFloat = 10.0
            let rightInset: CGFloat = 18.0 + rightInset
            let textRightInset: CGFloat = 0.0
            
            var updatedMediaReference: AnyMediaReference?
            var imageDimensions: CGSize?
            
            var titleString = strings.Conversation_PinnedMessage
            
            for media in message.media {
                if let image = media as? TelegramMediaImage {
                    updatedMediaReference = .message(message: MessageReference(message), media: image)
                    if let representation = largestRepresentationForPhoto(image) {
                        imageDimensions = representation.dimensions.cgSize
                    }
                    break
                } else if let file = media as? TelegramMediaFile {
                    updatedMediaReference = .message(message: MessageReference(message), media: file)
                    if !file.isInstantVideo, let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                        imageDimensions = representation.dimensions.cgSize
                    }
                    break
                } else if let _ = media as? TelegramMediaPoll {
                    titleString = strings.Conversation_PinnedPoll
                }
            }
            
            var applyImage: (() -> Void)?
            if let imageDimensions = imageDimensions {
                let boundingSize = CGSize(width: 35.0, height: 35.0)
                applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: 2.0), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                
                textLineInset += 9.0 + 35.0
            }
            
            var mediaUpdated = false
            if let updatedMediaReference = updatedMediaReference, let previousMediaReference = previousMediaReference {
                mediaUpdated = !updatedMediaReference.media.isEqual(to: previousMediaReference.media)
            } else if (updatedMediaReference != nil) != (previousMediaReference != nil) {
                mediaUpdated = true
            }
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedFetchMediaSignal: Signal<FetchResourceSourceType, FetchResourceError>?
            if mediaUpdated {
                if let updatedMediaReference = updatedMediaReference, imageDimensions != nil {
                    if let imageReference = updatedMediaReference.concrete(TelegramMediaImage.self) {
                        updateImageSignal = chatMessagePhotoThumbnail(account: context.account, photoReference: imageReference)
                    } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                        if fileReference.media.isAnimatedSticker {
                            let dimensions = fileReference.media.dimensions ?? PixelDimensions(width: 512, height: 512)
                            updateImageSignal = chatMessageAnimatedSticker(postbox: context.account.postbox, file: fileReference.media, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0)))
                            updatedFetchMediaSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: fileReference.resourceReference(fileReference.media.resource))
                        } else if fileReference.media.isVideo {
                            updateImageSignal = chatMessageVideoThumbnail(account: context.account, fileReference: fileReference)
                        } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                            updateImageSignal = chatWebpageSnippetFile(account: context.account, fileReference: fileReference, representation: iconImageRepresentation)
                        }
                    }
                } else {
                    updateImageSignal = .single({ _ in return nil })
                }
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: titleString, font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - textLineInset - contentLeftInset - rightInset - textRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0)))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: message, strings: strings, nameDisplayOrder: nameDisplayOrder, accountPeerId: accountPeerId).0, font: Font.regular(15.0), textColor: message.media.isEmpty || message.media.first is TelegramMediaWebpage ? theme.chat.inputPanel.primaryTextColor : theme.chat.inputPanel.secondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - textLineInset - contentLeftInset - rightInset - textRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0)))
            
            Queue.mainQueue().async {
                if let strongSelf = self {
                    let _ = titleApply()
                    let _ = textApply()
                    
                    strongSelf.previousMediaReference = updatedMediaReference
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: contentLeftInset + textLineInset, y: 5.0), size: titleLayout.size)
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: contentLeftInset + textLineInset, y: 23.0), size: textLayout.size)
                    
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: contentLeftInset + 9.0, y: 7.0), size: CGSize(width: 35.0, height: 35.0))
                    
                    if let applyImage = applyImage {
                        applyImage()
                        strongSelf.imageNode.isHidden = false
                    } else {
                        strongSelf.imageNode.isHidden = true
                    }
                    
                    if let updateImageSignal = updateImageSignal {
                        strongSelf.imageNode.setSignal(updateImageSignal)
                    }
                    if let updatedFetchMediaSignal = updatedFetchMediaSignal {
                        strongSelf.fetchDisposable.set(updatedFetchMediaSignal.start())
                    }
                }
            }
        }
    }
    
    @objc func tapped() {
        if let interfaceInteraction = self.interfaceInteraction, let message = self.currentMessage {
            interfaceInteraction.navigateToMessage(message.id)
        }
    }
    
    @objc func closePressed() {
        self.interfaceInteraction?.unpinMessage()
    }
}
