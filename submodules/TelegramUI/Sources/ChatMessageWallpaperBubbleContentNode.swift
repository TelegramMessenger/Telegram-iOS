import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import LocalizedPeerData
import TelegramStringFormatting
import WallpaperBackgroundNode
import PhotoResources
import WallpaperResources
import Markdown
import RadialStatusNode
import ComponentFlow
import AudioTranscriptionPendingIndicatorComponent

class ChatMessageWallpaperBubbleContentNode: ChatMessageBubbleContentNode {
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let mediaBackgroundNode: NavigationBackgroundNode
    private let subtitleNode: TextNode
    private let progressNode: ImmediateTextNode
    private let imageNode: TransformImageNode
    private var transcriptionPendingIndicator: ComponentHostView<Empty>?
    
    private var statusOverlayNode: ASDisplayNode
    private var statusNode: RadialStatusNode

    private let buttonNode: HighlightTrackingButtonNode
    private let buttonTitleNode: TextNode
    
    private var absoluteRect: (CGRect, CGSize)?
    
    private let fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
            
    required init() {
        self.mediaBackgroundNode = NavigationBackgroundNode(color: .clear)
        self.mediaBackgroundNode.clipsToBounds = true
        self.mediaBackgroundNode.cornerRadius = 24.0
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.progressNode = ImmediateTextNode()
        self.progressNode.isUserInteractionEnabled = false
        self.progressNode.displaysAsynchronously = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.clipsToBounds = true
        self.buttonNode.cornerRadius = 17.0
                        
        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.isUserInteractionEnabled = false
        self.buttonTitleNode.displaysAsynchronously = false
        
        self.statusOverlayNode = ASDisplayNode()
        self.statusOverlayNode.alpha = 0.0
        self.statusOverlayNode.clipsToBounds = true
        self.statusOverlayNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
        self.statusOverlayNode.cornerRadius = 50.0
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(rgb: 0x000000, alpha: 0.6))
        self.statusNode.isUserInteractionEnabled = false
        
        super.init()

        self.addSubnode(self.mediaBackgroundNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.progressNode)
        self.addSubnode(self.imageNode)
    
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.buttonTitleNode)
        
        self.addSubnode(self.statusOverlayNode)
        self.statusOverlayNode.addSubnode(self.statusNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonNode.alpha = 0.4
                    strongSelf.buttonTitleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonTitleNode.alpha = 0.4
                } else {
                    strongSelf.buttonNode.alpha = 1.0
                    strongSelf.buttonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.buttonTitleNode.alpha = 1.0
                    strongSelf.buttonTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOS 13.0, *) {
            self.statusOverlayNode.layer.cornerCurve = .circular
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.progressPressed))
        self.statusOverlayNode.view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc private func progressPressed() {
        guard let item = self.item else {
            return
        }
        item.context.account.pendingPeerMediaUploadManager.cancel(peerId: item.message.id.peerId)
    }
    
    override func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.item?.message.id == messageId {
            return (self.imageNode, self.imageNode.bounds, { [weak self] in
                guard let strongSelf = self else {
                    return (nil, nil)
                }
                
                let resultView = strongSelf.imageNode.view.snapshotContentTree(unhide: true)
                return (resultView, nil)
            })
        } else {
            return nil
        }
    }
    
    override func updateHiddenMedia(_ media: [Media]?) -> Bool {
        var mediaHidden = false
        var currentMedia: Media?
        if let item = item {
            mediaLoop: for media in item.message.media {
                if let media = media as? TelegramMediaAction {
                    switch media.action {
                    case let .suggestedProfilePhoto(image):
                        currentMedia = image
                        break mediaLoop
                    default:
                        break
                    }
                }
            }
        }
        if let currentMedia = currentMedia, let media = media {
            for item in media {
                if item.isSemanticallyEqual(to: currentMedia) {
                    mediaHidden = true
                    break
                }
            }
        }
        
        self.imageNode.isHidden = mediaHidden
        return mediaHidden
    }
    
    @objc private func buttonPressed() {
        guard let item = self.item else {
            return
        }
        let _ = item.controllerInteraction.openMessage(item.message, .default)
    }
    
    private func updateProgress(_ progress: Float?) {
        guard let item = self.item else {
            return
        }
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
        if let progress {
            let progressValue = CGFloat(max(0.027, progress))
            self.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: progressValue, cancelEnabled: true, animateRotation: true))
            transition.updateAlpha(node: self.statusOverlayNode, alpha: 1.0)
            
            let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
            self.progressNode.attributedText = NSAttributedString(string: "\(Int(progress * 100.0))%", font: Font.semibold(13.0), textColor: primaryTextColor, paragraphAlignment: .center)
            let progressSize = self.progressNode.updateLayout(CGSize(width: 100.0, height: 100.0))
            let progressFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(self.subtitleNode.frame.midX - progressSize.width / 2.0), y: self.subtitleNode.frame.maxY + 1.0), size: progressSize)
            self.progressNode.isHidden = false
            self.progressNode.frame = progressFrame
        } else {
            self.statusNode.transitionToState(.none)
            transition.updateAlpha(node: self.statusOverlayNode, alpha: 0.0)
            self.progressNode.isHidden = true
        }
    }
                
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeImageLayout = self.imageNode.asyncLayout()
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeButtonTitleLayout = TextNode.asyncLayout(self.buttonTitleNode)
        
        let currentItem = self.item

        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let width: CGFloat = 220.0
                let imageSize = CGSize(width: 100.0, height: 100.0)
                            
                let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                                
                var wallpaper: TelegramWallpaper?
                if let media = item.message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .setChatWallpaper(wallpaperValue) = media.action {
                    wallpaper = wallpaperValue
                }
                
                var mediaUpdated = true
                if let wallpaper = wallpaper, let media = currentItem?.message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .setChatWallpaper(currentWallpaper) = media.action {
                    mediaUpdated = wallpaper != currentWallpaper
                }
                
                var media: WallpaperPreviewMedia?
                if let wallpaper {
                    media = WallpaperPreviewMedia(wallpaper: wallpaper)
                }
                
                let fromYou = item.message.author?.id == item.context.account.peerId
                
                let peerName = item.message.peers[item.message.id.peerId].flatMap { EnginePeer($0).compactDisplayTitle } ?? ""
                let text: String
                var displayTrailingAnimatedDots = false
                if fromYou {
                    if item.message.id.namespace == Namespaces.Message.Local {
                        text = item.presentationData.strings.Notification_YouChangingWallpaper
                        displayTrailingAnimatedDots = true
                    } else {
                        text = item.presentationData.strings.Notification_YouChangedWallpaper
                    }
                } else {
                    text = item.presentationData.strings.Notification_ChangedWallpaper(peerName).string
                }
                
                let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor)
                let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: primaryTextColor)
                
                var subtitle = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in
                    return nil
                }), textAlignment: .center)
                if displayTrailingAnimatedDots {
                    let modifiedString = NSMutableAttributedString(attributedString: subtitle)
                    modifiedString.append(NSAttributedString(string: "...", font: Font.regular(13.0), textColor: .clear))
                    subtitle = modifiedString
                }
                
                let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitle, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Notification_Wallpaper_View, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
                var textHeight = subtitleLayout.size.height
                if displayTrailingAnimatedDots {
                    textHeight += subtitleLayout.size.height
                }
                let backgroundSize = CGSize(width: width, height: textHeight + 140.0 + (fromYou ? 0.0 : 42.0))
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            strongSelf.buttonNode.isHidden = fromYou
                            strongSelf.buttonTitleNode.isHidden = fromYou
                            
                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - imageSize.width) / 2.0), y: 13.0), size: imageSize)
                            if let media, mediaUpdated {     
                                let boundingSize = imageSize
                                var imageSize = boundingSize
                                let updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
                                var patternArguments: PatternWallpaperArguments?
                                switch media.content {
                                case let .file(file, patternColors, rotation, intensity, _, _):
                                    var representations: [ImageRepresentationWithReference] = file.previewRepresentations.map({ ImageRepresentationWithReference(representation: $0, reference: AnyMediaReference.message(message: MessageReference(item.message), media: file).resourceReference($0.resource)) })
                                    if file.mimeType == "image/svg+xml" || file.mimeType == "application/x-tgwallpattern" {
                                        representations.append(ImageRepresentationWithReference(representation: .init(dimensions: PixelDimensions(width: 1440, height: 2960), resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false), reference: AnyMediaReference.message(message: MessageReference(item.message), media: file).resourceReference(file.resource)))
                                        
                                        var colors: [UIColor] = []
                                        var customPatternColor: UIColor? = nil
                                        var bakePatternAlpha: CGFloat = 1.0
                                        if let intensity = intensity, intensity < 0 {
                                            if patternColors.isEmpty {
                                                colors.append(UIColor(rgb: 0xd6e2ee, alpha: 0.5))
                                            } else {
                                                colors.append(contentsOf: patternColors.map(UIColor.init(rgb:)))
                                            }
                                            customPatternColor = UIColor(white: 0.0, alpha: 1.0 - CGFloat(abs(intensity)))
                                        } else {
                                            if patternColors.isEmpty {
                                                colors.append(UIColor(rgb: 0xd6e2ee, alpha: 0.5))
                                            } else {
                                                colors.append(contentsOf: patternColors.map(UIColor.init(rgb:)))
                                            }
                                            let isLight = UIColor.average(of: patternColors.map(UIColor.init(rgb:))).hsb.b > 0.3
                                            customPatternColor = isLight ? .black : .white
                                            bakePatternAlpha = CGFloat(intensity ?? 50) / 100.0
                                        }
                                        patternArguments = PatternWallpaperArguments(colors: colors, rotation: rotation, customPatternColor: customPatternColor, bakePatternAlpha: bakePatternAlpha)
                                    }
                                    if ["image/png", "image/svg+xml", "application/x-tgwallpattern"].contains(file.mimeType) {
                                        updateImageSignal = patternWallpaperImage(account: item.context.account, accountManager: item.context.sharedContext.accountManager, representations: representations, mode: .thumbnail)
                                        |> mapToSignal { value -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> in
                                            if let value {
                                                return .single(value)
                                            } else {
                                                return .complete()
                                            }
                                        }
                                    } else {
                                        if let dimensions = file.dimensions?.cgSize {
                                            imageSize = dimensions.aspectFilled(boundingSize)
                                        }
                                        updateImageSignal = wallpaperImage(account: item.context.account, accountManager: item.context.sharedContext.accountManager, fileReference: FileMediaReference.message(message: MessageReference(item.message), media: file), representations: representations, alwaysShowThumbnailFirst: true, thumbnail: true, autoFetchFullSize: true, blurred: wallpaper?.settings?.blur == true)
                                    }
                                case let .image(representations):
                                    if let dimensions = representations.last?.dimensions.cgSize {
                                        imageSize = dimensions.aspectFilled(boundingSize)
                                    }
                                    updateImageSignal = wallpaperImage(account: item.context.account, accountManager: item.context.sharedContext.accountManager, fileReference: nil, representations: representations.map({ ImageRepresentationWithReference(representation: $0, reference: .standalone(resource: $0.resource)) }), alwaysShowThumbnailFirst: true, thumbnail: true, autoFetchFullSize: true, blurred: wallpaper?.settings?.blur == true)
                                case let .color(color):
                                    updateImageSignal = solidColorImage(color)
                                case let .gradient(colors, rotation):
                                    updateImageSignal = gradientImage(colors.map(UIColor.init(rgb:)), rotation: rotation ?? 0)
                                case .themeSettings:
                                    updateImageSignal = .complete()
                                }
                                
                                strongSelf.imageNode.setSignal(updateImageSignal, attemptSynchronously: synchronousLoads)
                                
                                let arguments = TransformImageArguments(corners: ImageCorners(radius: boundingSize.width / 2.0), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), custom: patternArguments)
                                let apply = makeImageLayout(arguments)
                                apply()
                                
                                strongSelf.imageNode.frame = imageFrame
                            }
                            
                            let radialStatusSize: CGFloat = 50.0
                            strongSelf.statusOverlayNode.frame = imageFrame
                            strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.width - radialStatusSize) / 2.0), y: floor((imageFrame.height - radialStatusSize) / 2.0)), size: CGSize(width: radialStatusSize, height: radialStatusSize))
                            
                            if mediaUpdated {
                                if item.message.id.namespace == Namespaces.Message.Local {
                                    strongSelf.statusDisposable.set((item.context.account.pendingPeerMediaUploadManager.uploadProgress(messageId: item.message.id)
                                    |> deliverOnMainQueue).start(next: { [weak self] progress in
                                        if let strongSelf = self {
                                            strongSelf.updateProgress(progress)
                                        }
                                    }))
                                } else {
                                    strongSelf.statusDisposable.set(nil)
                                    strongSelf.updateProgress(nil)
                                }
                            }
                            
                            let mediaBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - width) / 2.0), y: 0.0), size: backgroundSize)
                            strongSelf.mediaBackgroundNode.frame = mediaBackgroundFrame
                                                        
                            strongSelf.mediaBackgroundNode.updateColor(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: item.controllerInteraction.enableFullTranslucency && dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), transition: .immediate)
                            strongSelf.mediaBackgroundNode.update(size: mediaBackgroundFrame.size, transition: .immediate)
                            strongSelf.buttonNode.backgroundColor = item.presentationData.theme.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
                            
                            let _ = subtitleApply()
                            let _ = buttonTitleApply()
                                                        
                            let subtitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - subtitleLayout.size.width) / 2.0) , y: mediaBackgroundFrame.minY + 127.0), size: subtitleLayout.size)
                            strongSelf.subtitleNode.frame = subtitleFrame
                            
                            if displayTrailingAnimatedDots {
                                let transcriptionPendingIndicator: ComponentHostView<Empty>
                                if let current = strongSelf.transcriptionPendingIndicator {
                                    transcriptionPendingIndicator = current
                                } else {
                                    transcriptionPendingIndicator = ComponentHostView<Empty>()
                                    strongSelf.transcriptionPendingIndicator = transcriptionPendingIndicator
                                    strongSelf.view.addSubview(transcriptionPendingIndicator)
                                }
                                
                                let indicatorComponent: AnyComponent<Empty>
                                indicatorComponent = AnyComponent(AudioTranscriptionPendingLottieIndicatorComponent(color: primaryTextColor, font: Font.regular(13.0)))
                                
                                let indicatorSize = transcriptionPendingIndicator.update(
                                    transition: .immediate,
                                    component: indicatorComponent,
                                    environment: {},
                                    containerSize: CGSize(width: 100.0, height: 100.0)
                                )
                                
                                transcriptionPendingIndicator.frame = CGRect(origin: CGPoint(x: strongSelf.subtitleNode.frame.midX + subtitleLayout.trailingLineWidth / 2.0 - indicatorSize.width + 2.0 - UIScreenPixel, y: strongSelf.subtitleNode.frame.maxY - indicatorSize.height - 3.0 - UIScreenPixel), size: indicatorSize)
                            } else {
                                if let transcriptionPendingIndicator = strongSelf.transcriptionPendingIndicator {
                                    strongSelf.transcriptionPendingIndicator = nil
                                    transcriptionPendingIndicator.removeFromSuperview()
                                }
                            }
                            
                            let buttonTitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonTitleLayout.size.width) / 2.0), y: subtitleFrame.maxY + 18.0), size: buttonTitleLayout.size)
                            strongSelf.buttonTitleNode.frame = buttonTitleFrame
                            
                            let buttonSize = CGSize(width: buttonTitleLayout.size.width + 38.0, height: 34.0)
                            strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonSize.width) / 2.0), y: subtitleFrame.maxY + 10.0), size: buttonSize)

                            if item.controllerInteraction.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true {
                                if strongSelf.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                    strongSelf.mediaBackgroundNode.isHidden = true
                                    backgroundContent.clipsToBounds = true
                                    backgroundContent.allowsGroupOpacity = true
                                    backgroundContent.cornerRadius = 24.0

                                    strongSelf.mediaBackgroundContent = backgroundContent
                                    strongSelf.insertSubnode(backgroundContent, at: 0)
                                }
                                
                                strongSelf.mediaBackgroundContent?.frame = mediaBackgroundFrame
                            } else {
                                strongSelf.mediaBackgroundNode.isHidden = false
                                strongSelf.mediaBackgroundContent?.removeFromSupernode()
                                strongSelf.mediaBackgroundContent = nil
                            }
                            
                            if let (rect, size) = strongSelf.absoluteRect {
                                strongSelf.updateAbsoluteRect(rect, within: size)
                            }
                        }
                    })
                })
            })
        }
    }

    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        if let mediaBackgroundContent = self.mediaBackgroundContent {
            var backgroundFrame = mediaBackgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            mediaBackgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.statusOverlayNode.alpha > 0.0 {
            return .none
        } else if self.mediaBackgroundNode.frame.contains(point) {
            return .openMessage
        } else {
            return .none
        }
    }
}
