import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import StickerResources
import PhotoResources
import TelegramStringFormatting
import AnimatedCountLabelNode
import AnimatedNavigationStripeNode
import ContextUI
import RadialStatusNode
import TextFormat
import ChatPresentationInterfaceState
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import TranslateUI
import ChatControllerInteraction

private enum PinnedMessageAnimation {
    case slideToTop
    case slideToBottom
}

final class ChatAdPanelNode: ASDisplayNode {
    private let context: AccountContext
    private(set) var message: Message?
    
    var controllerInteraction: ChatControllerInteraction?
    
    private let tapButton: HighlightTrackingButtonNode
    
    private let contextContainer: ContextControllerSourceNode
    private let clippingContainer: ASDisplayNode
    private let contentContainer: ASDisplayNode
    private let contentTextContainer: ASDisplayNode
    private let adNode: TextNode
    private let titleNode: TextNode
    private let textNode: TextNodeWithEntities
    
    private let removeButtonNode: HighlightTrackingButtonNode
    private let removeBackgroundNode: ASImageNode
    private let removeTextNode: ImmediateTextNode
    
    private let closeButton: HighlightableButtonNode
    
    private let imageNode: TransformImageNode
    private let imageNodeContainer: ASDisplayNode

    private let separatorNode: ASDisplayNode

    private var currentLayout: (CGFloat, CGFloat, CGFloat)?
    private var currentMessage: Message?
    private var previousMediaReference: AnyMediaReference?
        
    private let fetchDisposable = MetaDisposable()
        
    private let animationCache: AnimationCache?
    private let animationRenderer: MultiAnimationRenderer?
            
    init(context: AccountContext, animationCache: AnimationCache?, animationRenderer: MultiAnimationRenderer?) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        
        self.tapButton = HighlightTrackingButtonNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.contextContainer = ContextControllerSourceNode()
        
        self.clippingContainer = ASDisplayNode()
        self.clippingContainer.clipsToBounds = true
        
        self.contentContainer = ASDisplayNode()
        self.contentTextContainer = ASDisplayNode()
        
        self.adNode = TextNode()
        self.adNode.displaysAsynchronously = false
        self.adNode.isUserInteractionEnabled = false
        
        self.removeButtonNode = HighlightTrackingButtonNode()
        self.removeBackgroundNode = ASImageNode()
        
        self.removeTextNode = ImmediateTextNode()
        self.removeTextNode.displaysAsynchronously = false
        self.removeTextNode.isUserInteractionEnabled = false
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        
        self.textNode = TextNodeWithEntities()
        self.textNode.textNode.displaysAsynchronously = false
        self.textNode.textNode.isUserInteractionEnabled = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        
        self.imageNodeContainer = ASDisplayNode()
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
    
        super.init()
                
        self.addSubnode(self.contextContainer)
        
        self.contextContainer.addSubnode(self.clippingContainer)
        self.clippingContainer.addSubnode(self.contentContainer)
        self.contentTextContainer.addSubnode(self.titleNode)
        
        self.contentTextContainer.addSubnode(self.adNode)
                
        self.contentTextContainer.addSubnode(self.textNode.textNode)
        self.contentContainer.addSubnode(self.contentTextContainer)
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.contentContainer.addSubnode(self.imageNodeContainer)
                
        self.tapButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        self.tapButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.adNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.adNode.alpha = 0.4
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.textNode.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.textNode.alpha = 0.4
                    strongSelf.imageNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.imageNode.alpha = 0.4
                    strongSelf.removeTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.removeTextNode.alpha = 0.4
                    strongSelf.removeBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.removeBackgroundNode.alpha = 0.4
                } else {
                    strongSelf.adNode.alpha = 1.0
                    strongSelf.adNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.textNode.textNode.alpha = 1.0
                    strongSelf.textNode.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.imageNode.alpha = 1.0
                    strongSelf.imageNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.removeTextNode.alpha = 1.0
                    strongSelf.removeTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.removeBackgroundNode.alpha = 1.0
                    strongSelf.removeBackgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.contextContainer.addSubnode(self.tapButton)
        
        self.contextContainer.addSubnode(self.removeBackgroundNode)
        self.contextContainer.addSubnode(self.removeTextNode)
        self.contextContainer.addSubnode(self.removeButtonNode)
        
        self.addSubnode(self.separatorNode)
        
        self.removeButtonNode.addTarget(self, action: #selector(self.removePressed), forControlEvents: [.touchUpInside])
        self.removeButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.removeTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.removeTextNode.alpha = 0.4
                    strongSelf.removeBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.removeBackgroundNode.alpha = 0.4
                } else {
                    strongSelf.removeTextNode.alpha = 1.0
                    strongSelf.removeTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.removeBackgroundNode.alpha = 1.0
                    strongSelf.removeBackgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.contextContainer.activated = { [weak self] gesture, _ in
            guard let self, let message = self.message else {
                return
            }
            self.controllerInteraction?.adContextAction(message, self.contextContainer, gesture)
        }
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    private var theme: PresentationTheme?
    
    @objc private func closePressed() {
        if self.context.isPremium, let adAttribute = self.message?.adAttribute {
            self.controllerInteraction?.removeAd(adAttribute.opaqueId)
        } else {
            self.controllerInteraction?.openNoAdsDemo()
        }
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        self.message = interfaceState.adMessage
                
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
            self.removeBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 15.0, color: interfaceState.theme.chat.inputPanel.panelControlAccentColor.withMultipliedAlpha(0.1))
            self.removeTextNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_BotAd_WhatIsThis, font: Font.regular(11.0), textColor: interfaceState.theme.chat.inputPanel.panelControlAccentColor)
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(interfaceState.theme), for: [])
        }
                
        self.contextContainer.isGestureEnabled = false
        
        let panelHeight: CGFloat
        var hasCloseButton = true
        if let message = interfaceState.adMessage {
            panelHeight = self.enqueueTransition(width: width, leftInset: leftInset, rightInset: rightInset, transition: .immediate, animation: nil, message: message, theme: interfaceState.theme, strings: interfaceState.strings, nameDisplayOrder: interfaceState.nameDisplayOrder, dateTimeFormat: interfaceState.dateTimeFormat, accountPeerId: self.context.account.peerId, firstTime: false, isReplyThread: false, translateToLanguage: nil)
            hasCloseButton = message.media.isEmpty
        } else {
            panelHeight = 50.0
        }
        
        self.contextContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        self.tapButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
                
        self.clippingContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        self.contentContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        
        let contentRightInset: CGFloat = 14.0 + rightInset
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        self.closeButton.frame = CGRect(origin: CGPoint(x: width - contentRightInset - closeButtonSize.width, y: floorToScreenPixels((panelHeight - closeButtonSize.height) / 2.0)), size: closeButtonSize)
        
        self.closeButton.isHidden = !hasCloseButton
        
        self.currentLayout = (width, leftInset, rightInset)
        
        return panelHeight
    }
    
    private func enqueueTransition(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, animation: PinnedMessageAnimation?, message: Message, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, accountPeerId: PeerId, firstTime: Bool, isReplyThread: Bool, translateToLanguage: String?) -> CGFloat {
        var animationTransition: ContainedViewLayoutTransition = .immediate
        
        if let animation = animation {
            animationTransition = .animated(duration: 0.2, curve: .easeInOut)
            
            if let copyView = self.textNode.textNode.view.snapshotView(afterScreenUpdates: false) {
                let offset: CGFloat
                switch animation {
                case .slideToTop:
                    offset = -10.0
                case .slideToBottom:
                    offset = 10.0
                }
                
                copyView.frame = self.textNode.textNode.frame
                self.textNode.textNode.view.superview?.addSubview(copyView)
                copyView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.2, removeOnCompletion: false, additive: true)
                copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyView] _ in
                    copyView?.removeFromSuperview()
                })
                self.textNode.textNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -offset), to: CGPoint(), duration: 0.2, additive: true)
                self.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
        
        let makeAdLayout = TextNode.asyncLayout(self.adNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNodeWithEntities.asyncLayout(self.textNode)
        let imageNodeLayout = self.imageNode.asyncLayout()
        
        let previousMediaReference = self.previousMediaReference
        let context = self.context
        
        let contentLeftInset: CGFloat = leftInset + 18.0
        let contentRightInset: CGFloat = rightInset + 9.0
        
        var textRightInset: CGFloat = 0.0
                
        var updatedMediaReference: AnyMediaReference?
        var imageDimensions: CGSize?
                    
        if !message.containsSecretMedia {
            for media in message.media {
                if let image = media as? TelegramMediaImage {
                    updatedMediaReference = .message(message: MessageReference(message), media: image)
                    if let representation = largestRepresentationForPhoto(image) {
                        imageDimensions = representation.dimensions.cgSize
                    }
                    break
                } else if let file = media as? TelegramMediaFile {
                    updatedMediaReference = .message(message: MessageReference(message), media: file)
                    if !file.isInstantVideo && !file.isSticker, let representation = largestImageRepresentation(file.previewRepresentations) {
                        imageDimensions = representation.dimensions.cgSize
                    } else if file.isAnimated, let dimensions = file.dimensions {
                        imageDimensions = dimensions.cgSize
                    }
                    break
                } else if let paidContent = media as? TelegramMediaPaidContent, let firstMedia = paidContent.extendedMedia.first {
                    switch firstMedia {
                    case let .preview(dimensions, immediateThumbnailData, _):
                        let thumbnailMedia = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [], immediateThumbnailData: immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                        if let dimensions {
                            imageDimensions = dimensions.cgSize
                        }
                        updatedMediaReference = .standalone(media: thumbnailMedia)
                    case let .full(fullMedia):
                        updatedMediaReference = .message(message: MessageReference(message), media: fullMedia)
                        if let image = fullMedia as? TelegramMediaImage {
                            if let representation = largestRepresentationForPhoto(image) {
                                imageDimensions = representation.dimensions.cgSize
                            }
                            break
                        } else if let file = fullMedia as? TelegramMediaFile {
                            if let dimensions = file.dimensions {
                                imageDimensions = dimensions.cgSize
                            }
                            break
                        }
                    }
                }
            }
        }
                    
        let imageBoundingSize = CGSize(width: 48.0, height: 48.0)
        var applyImage: (() -> Void)?
        if let imageDimensions {
            applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: 3.0), imageSize: imageDimensions.aspectFilled(imageBoundingSize), boundingSize: imageBoundingSize, intrinsicInsets: UIEdgeInsets()))
            textRightInset += imageBoundingSize.width + 18.0
        } else {
            textRightInset = 27.0
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
                    if imageReference.media.representations.isEmpty {
                        updateImageSignal = chatSecretPhoto(account: context.account, userLocation: .peer(message.id.peerId), photoReference: imageReference, ignoreFullSize: true, synchronousLoad: true)
                    } else {
                        updateImageSignal = chatMessagePhotoThumbnail(account: context.account, userLocation: .peer(message.id.peerId), photoReference: imageReference, blurred: false)
                    }
                } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                    if fileReference.media.isAnimatedSticker {
                        let dimensions = fileReference.media.dimensions ?? PixelDimensions(width: 512, height: 512)
                        updateImageSignal = chatMessageAnimatedSticker(postbox: context.account.postbox, userLocation: .peer(message.id.peerId), file: fileReference.media, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0)))
                        updatedFetchMediaSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(message.id.peerId), userContentType: MediaResourceUserContentType(file: fileReference.media), reference: fileReference.resourceReference(fileReference.media.resource))
                    } else if fileReference.media.isVideo || fileReference.media.isAnimated {
                        updateImageSignal = chatMessageVideoThumbnail(account: context.account, userLocation: .peer(message.id.peerId), fileReference: fileReference, blurred: false)
                    } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                        updateImageSignal = chatWebpageSnippetFile(account: context.account, userLocation: .peer(message.id.peerId), mediaReference: fileReference.abstract, representation: iconImageRepresentation)
                    }
                }
            } else {
                updateImageSignal = .single({ _ in return nil })
            }
        }
        
        let textConstrainedSize = CGSize(width: width - contentLeftInset - contentRightInset - textRightInset, height: CGFloat.greatestFiniteMagnitude)
                
        let (adLayout, adApply) = makeAdLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: strings.Chat_BotAd_Title, font: Font.semibold(14.0), textColor: theme.chat.inputPanel.panelControlAccentColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: .zero))
        
        var titleText: String = ""
        if let author = message.author {
            titleText = EnginePeer(author).compactDisplayTitle
        }
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: titleText, font: Font.semibold(14.0), textColor: theme.chat.inputPanel.primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: .zero))
        
        let (textString, _, isText) = descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, accountPeerId: accountPeerId)
        
        let messageText: NSAttributedString
        let textFont = Font.regular(14.0)
        if isText {
            var text = message.text
            var messageEntities = message.textEntitiesAttribute?.entities ?? []
            
            if let translateToLanguage = translateToLanguage, !text.isEmpty {
                for attribute in message.attributes {
                    if let attribute = attribute as? TranslationMessageAttribute, !attribute.text.isEmpty, attribute.toLang == translateToLanguage {
                        text = attribute.text
                        messageEntities = attribute.entities
                        break
                    }
                }
            }
            
            let entities = messageEntities.filter { entity in
                switch entity.type {
                case .CustomEmoji:
                    return true
                default:
                    return false
                }
            }
            let textColor = theme.chat.inputPanel.primaryTextColor
            if entities.count > 0 {
                messageText = stringWithAppliedEntities(trimToLineCount(text, lineCount: 1), entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: message)
            } else {
                messageText = NSAttributedString(string: foldLineBreaks(text), font: textFont, textColor: textColor)
            }
        } else {
            messageText = NSAttributedString(string: foldLineBreaks(textString.string), font: textFont, textColor: message.media.isEmpty || message.media.first is TelegramMediaWebpage ? theme.chat.inputPanel.primaryTextColor : theme.chat.inputPanel.secondaryTextColor)
        }
        
        let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: messageText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: .zero))
        
        var panelHeight: CGFloat = 0.0
        if let _ = imageDimensions {
            panelHeight = 9.0 + imageBoundingSize.height + 9.0
        }
        
        var textHeight: CGFloat
        var titleOnSeparateLine = false
        if textLayout.numberOfLines == 1 || contentLeftInset + adLayout.size.width + 2.0 + titleLayout.size.width > width - contentRightInset - textRightInset {
            textHeight = adLayout.size.height + titleLayout.size.height + textLayout.size.height + 15.0
            titleOnSeparateLine = true
        } else {
            textHeight = titleLayout.size.height + textLayout.size.height + 15.0
        }
        
        panelHeight = max(panelHeight, textHeight)
        
        Queue.mainQueue().async {
            let _ = adApply()
            let _ = titleApply()
            
            var textArguments: TextNodeWithEntities.Arguments?
            if let cache = self.animationCache, let renderer = self.animationRenderer {
                textArguments = TextNodeWithEntities.Arguments(
                    context: self.context,
                    cache: cache,
                    renderer: renderer,
                    placeholderColor: theme.list.mediaPlaceholderColor,
                    attemptSynchronous: false
                )
            }
            let _ = textApply(textArguments)
            
            self.previousMediaReference = updatedMediaReference
            
            let textContainerFrame = CGRect(origin: CGPoint(x: contentLeftInset, y: 0.0), size: CGSize(width: width, height: panelHeight))
            animationTransition.updateFrameAdditive(node: self.contentTextContainer, frame: textContainerFrame)
            
            let removeTextSize = self.removeTextNode.updateLayout(CGSize(width: width, height: .greatestFiniteMagnitude))
            
            if titleOnSeparateLine {
                self.adNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 9.0), size: adLayout.size)
                self.titleNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 26.0), size: titleLayout.size)
                self.textNode.textNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 43.0), size: textLayout.size)
                
                self.removeTextNode.frame = CGRect(origin: CGPoint(x: contentLeftInset + adLayout.size.width + 8.0, y: 11.0 - UIScreenPixel), size: removeTextSize)
                self.removeBackgroundNode.frame = self.removeTextNode.frame.insetBy(dx: -5.0, dy: -1.0)
                self.removeButtonNode.frame = self.removeBackgroundNode.frame
            } else {
                self.adNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 9.0), size: adLayout.size)
                self.titleNode.frame = CGRect(origin: CGPoint(x: adLayout.size.width + 2.0, y: 9.0), size: titleLayout.size)
                self.textNode.textNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 26.0), size: textLayout.size)
                
                self.removeTextNode.frame = CGRect(origin: CGPoint(x: contentLeftInset + adLayout.size.width + 2.0 + titleLayout.size.width + 8.0, y: 11.0 - UIScreenPixel), size: removeTextSize)
                self.removeBackgroundNode.frame = self.removeTextNode.frame.insetBy(dx: -5.0, dy: -1.0)
                self.removeButtonNode.frame = self.removeBackgroundNode.frame
            }
                                
            self.textNode.visibilityRect = CGRect.infinite
             
            self.imageNodeContainer.frame = CGRect(origin: CGPoint(x: width - contentRightInset - imageBoundingSize.width, y: 9.0), size: imageBoundingSize)
            self.imageNode.frame = CGRect(origin: CGPoint(), size: imageBoundingSize)
            
            if let applyImage = applyImage {
                applyImage()
                
                animationTransition.updateSublayerTransformScale(node: self.imageNodeContainer, scale: 1.0)
                animationTransition.updateAlpha(node: self.imageNodeContainer, alpha: 1.0, beginWithCurrentState: true)
            } else {
                animationTransition.updateSublayerTransformScale(node: self.imageNodeContainer, scale: 0.1)
                animationTransition.updateAlpha(node: self.imageNodeContainer, alpha: 0.0, beginWithCurrentState: true)
            }
            
            if let updateImageSignal = updateImageSignal {
                self.imageNode.setSignal(updateImageSignal)
            }
            if let updatedFetchMediaSignal = updatedFetchMediaSignal {
                self.fetchDisposable.set(updatedFetchMediaSignal.startStrict())
            }
        }
        
        return panelHeight
    }
    
    @objc func tapped() {
        guard let message = self.message else {
            return
        }
        self.controllerInteraction?.activateAdAction(message.id, nil, false, false)
    }
    
    @objc func removePressed() {
        guard let message = self.message else {
            return
        }
        self.controllerInteraction?.adContextAction(message, self.contextContainer, nil)
    }
}
