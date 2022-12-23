import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TextFormat
import Markdown
import RadialStatusNode
import AppBundle
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SlotMachineAnimationNode
import AnimationUI
import StickerResources
import AvatarNode
import AccountContext
import AnimatedAvatarSetNode

final class UndoOverlayControllerNode: ViewControllerTracingNode {
    private let elevatedLayout: Bool
    private let placementPosition: UndoOverlayController.Position
    private var statusNode: RadialStatusNode?
    private let timerTextNode: ImmediateTextNode
    private let avatarNode: AvatarNode?
    private let iconNode: ASImageNode?
    private var multiAvatarsNode: AnimatedAvatarSetNode?
    private var multiAvatarsSize: CGSize?
    private var iconImageSize: CGSize?
    private let iconCheckNode: RadialStatusNode?
    private let animationNode: AnimationNode?
    private var animatedStickerNode: AnimatedStickerNode?
    private var slotMachineNode: SlotMachineAnimationNode?
    private var stillStickerNode: TransformImageNode?
    private var stickerImageSize: CGSize?
    private var stickerOffset: CGPoint?
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode
    private let undoButtonTextNode: ImmediateTextNode
    private let undoButtonNode: HighlightTrackingButtonNode
    private let panelNode: ASDisplayNode
    private let panelWrapperNode: ASDisplayNode
    private let action: (UndoOverlayAction) -> Bool
    private let dismiss: () -> Void
    
    private var content: UndoOverlayContent
    
    private let effectView: UIView
    
    private let animationBackgroundColor: UIColor
        
    private var originalRemainingSeconds: Double
    private var remainingSeconds: Double
    private var timer: SwiftSignalKit.Timer?
    
    private var validLayout: ContainerViewLayout?
    
    private var fetchResourceDisposable: Disposable?
    
    init(presentationData: PresentationData, content: UndoOverlayContent, elevatedLayout: Bool, placementPosition: UndoOverlayController.Position, action: @escaping (UndoOverlayAction) -> Bool, dismiss: @escaping () -> Void) {
        self.elevatedLayout = elevatedLayout
        self.placementPosition = placementPosition
        self.content = content
        
        self.action = action
        self.dismiss = dismiss
        
        self.timerTextNode = ImmediateTextNode()
        self.timerTextNode.displaysAsynchronously = false
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 0
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        var displayUndo = true
        var undoText = presentationData.strings.Undo_Undo
        var undoTextColor = UIColor(rgb: 0x5ac8fa)
        undoTextColor = presentationData.theme.list.itemAccentColor.withMultiplied(hue: 1.0, saturation: 0.64, brightness: 1.08)
        
        if presentationData.theme.overallDarkAppearance {
            self.animationBackgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
        } else {
            self.animationBackgroundColor = UIColor(rgb: 0x474747)
        }
        
        var isUserInteractionEnabled = false
        switch content {
            case let .removedChat(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                self.animatedStickerNode = nil
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = true
                self.originalRemainingSeconds = 5
                self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
            case let .archivedChat(_, title, text, undo):
                self.avatarNode = nil
                if undo {
                    self.iconNode = ASImageNode()
                    self.iconNode?.displayWithoutProcessing = true
                    self.iconNode?.displaysAsynchronously = false
                    self.iconNode?.image = UIImage(bundleImageName: "Chat List/ArchivedUndoIcon")
                    self.iconCheckNode = RadialStatusNode(backgroundNodeColor: .clear)
                    self.iconCheckNode?.frame = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)
                    self.animationNode = nil
                } else {
                    self.iconNode = nil
                    self.iconCheckNode = nil
                    self.animationNode = AnimationNode(animation: "anim_infotip", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                }
                self.animatedStickerNode = nil
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = undo
                self.originalRemainingSeconds = 5
            case let .hidArchive(title, text, undo):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_archiveswipe", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
            
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = undo
                self.originalRemainingSeconds = 3
            case let .revealedArchive(title, text, undo):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_infotip", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
            
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = undo
                self.originalRemainingSeconds = 3
            case let .autoDelete(isOn, title, text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: isOn ? "anim_autoremove_on" : "anim_autoremove_off", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
                
                if let title = title {
                    self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                }
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = false
                self.originalRemainingSeconds = 3.5
            case let .succeed(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_success", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 5
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .info(title, text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_infotip", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
            
                if let title = title {
                    self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                }
            
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { contents in
                    return ("URL", contents)
                }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = Double(max(5, min(8, text.count / 14)))
            
                if text.contains("](") {
                    isUserInteractionEnabled = true
                }
            case let .actionSucceeded(title, text, cancel):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_success", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
                
                undoTextColor = UIColor(rgb: 0xff7b74)
            
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                self.textNode.attributedText = attributedText
                displayUndo = true
                undoText = cancel
                self.originalRemainingSeconds = 5
            case let .linkCopied(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_linkcopied", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
            
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .banned(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_banned", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
            
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .importedMessage(text):
                self.avatarNode = nil
                self.iconNode = ASImageNode()
                self.iconNode?.displayWithoutProcessing = true
                self.iconNode?.displaysAsynchronously = false
                self.iconNode?.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/ImportedMessageTooltipIcon"), color: .white)
                self.iconCheckNode = nil
                self.animationNode = nil
                self.animatedStickerNode = nil
            
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .chatAddedToFolder(chatTitle, folderTitle):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_success", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
                
                let formattedString = presentationData.strings.ChatList_AddedToFolderTooltip(chatTitle, folderTitle)
                
                let string = NSMutableAttributedString(attributedString: NSAttributedString(string: formattedString.string, font: Font.regular(14.0), textColor: .white))
                for range in formattedString.ranges {
                    string.addAttribute(.font, value: Font.regular(14.0), range: range.range)
                }
                
                self.textNode.attributedText = string
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .chatRemovedFromFolder(chatTitle, folderTitle):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_success", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil

                let formattedString = presentationData.strings.ChatList_RemovedFromFolderTooltip(chatTitle, folderTitle)
                
                let string = NSMutableAttributedString(attributedString: NSAttributedString(string: formattedString.string, font: Font.regular(14.0), textColor: .white))
                for range in formattedString.ranges {
                    string.addAttribute(.font, value: Font.regular(14.0), range: range.range)
                }
                
                self.textNode.attributedText = string
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .paymentSent(currencyValue, itemTitle):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_payment", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
                
                let formattedString = presentationData.strings.Checkout_SuccessfulTooltip(currencyValue, itemTitle)

                let string = NSMutableAttributedString(attributedString: NSAttributedString(string: formattedString.string, font: Font.regular(14.0), textColor: .white))
                for range in formattedString.ranges {
                    string.addAttribute(.font, value: Font.semibold(14.0), range: range.range)
                }

                self.textNode.attributedText = string
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .messagesUnpinned(title, text, undo, isHidden):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: isHidden ? "anim_message_hidepin" : "anim_message_unpin", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                if !text.isEmpty {
                    self.textNode.attributedText = attributedText
                }
                
                displayUndo = undo
                self.originalRemainingSeconds = 5
            case let .emoji(name, text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                self.animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                self.animatedStickerNode?.visibility = true
                self.animatedStickerNode?.setup(source: AnimatedStickerNodeLocalFileSource(name: name), width: 100, height: 100, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .swipeToReply(title, text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_swipereply", colors: [:], scale: 1.0)
                self.animatedStickerNode = nil
                
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .stickersModified(title, text, undo, info, topItem, context):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                
                let stillStickerNode = TransformImageNode()
                
                self.stillStickerNode = stillStickerNode
                
                enum StickerPackThumbnailItem {
                    case still(TelegramMediaImageRepresentation)
                    case animated(EngineMediaResource, PixelDimensions, Bool)
                }
                
                var thumbnailItem: StickerPackThumbnailItem?
                var resourceReference: MediaResourceReference?
                
                if let thumbnail = info.thumbnail {
                    if info.flags.contains(.isAnimated) || info.flags.contains(.isVideo) {
                        thumbnailItem = .animated(EngineMediaResource(thumbnail.resource), thumbnail.dimensions, info.flags.contains(.isVideo))
                    } else {
                        thumbnailItem = .still(thumbnail)
                    }
                    resourceReference = MediaResourceReference.stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource)
                } else if let item = topItem {
                    if item.file.isAnimatedSticker || item.file.isVideoSticker {
                        thumbnailItem = .animated(EngineMediaResource(item.file.resource), item.file.dimensions ?? PixelDimensions(width: 512, height: 512), item.file.isVideoSticker)
                        resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: item.file.resource)
                    } else if let dimensions = item.file.dimensions, let resource = chatMessageStickerResource(file: item.file, small: true) as? TelegramMediaResource {
                        thumbnailItem = .still(TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false))
                        resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: resource)
                    }
                }
                
                var updatedImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var updatedFetchSignal: Signal<Never, EngineMediaResource.Fetch.Error>?
                
                let imageBoundingSize = CGSize(width: 34.0, height: 34.0)
                
                if let thumbnailItem = thumbnailItem {
                    switch thumbnailItem {
                    case let .still(representation):
                        let stillImageSize = representation.dimensions.cgSize.aspectFitted(imageBoundingSize)
                        self.stickerImageSize = stillImageSize
                        
                        updatedImageSignal = chatMessageStickerPackThumbnail(postbox: context.account.postbox, resource: representation.resource)
                    case let .animated(resource, dimensions, _):
                        self.stickerImageSize = dimensions.cgSize.aspectFitted(imageBoundingSize)
                        
                        updatedImageSignal = chatMessageStickerPackThumbnail(postbox: context.account.postbox, resource: resource._asResource(), animated: true)
                    }
                    if let resourceReference = resourceReference {
                        updatedFetchSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: resourceReference)
                        |> mapError { _ -> EngineMediaResource.Fetch.Error in
                            return .generic
                        }
                        |> ignoreValues
                    }
                } else {
                    updatedImageSignal = .single({ _ in return nil })
                    updatedFetchSignal = .complete()
                }
                
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                displayUndo = undo
                self.originalRemainingSeconds = 2
            
                if let updatedFetchSignal = updatedFetchSignal {
                    self.fetchResourceDisposable = updatedFetchSignal.start()
                }
            
                if let updatedImageSignal = updatedImageSignal {
                    stillStickerNode.setSignal(updatedImageSignal)
                }
            
                if let thumbnailItem = thumbnailItem {
                    switch thumbnailItem {
                    case .still:
                        break
                    case let .animated(resource, _, isVideo):
                        let animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                        self.animatedStickerNode = animatedStickerNode
                        animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: context.account, resource: resource._asResource(), isVideo: isVideo), width: 80, height: 80, mode: .direct(cachePathPrefix: nil))
                    }
                }
            case let .dice(dice, context, text, action):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                if let action = action {
                    displayUndo = true
                    undoText = action
                } else {
                    displayUndo = false
                }
                self.originalRemainingSeconds = 5
                
                self.stickerImageSize = CGSize(width: 42.0, height: 42.0)
                
                switch dice.emoji {
                    case "🎲":
                        self.stickerOffset = CGPoint(x: 0.0, y: -7.0)
                    default:
                        break
                }
                
                if dice.emoji == "🎰" {
                    let slotMachineNode = SlotMachineAnimationNode(account: context.account, size: CGSize(width: 42.0, height: 42.0))
                    self.slotMachineNode = slotMachineNode
                    
                    slotMachineNode.setState(.rolling)
                    if let value = dice.value {
                        slotMachineNode.setState(.value(value, true))
                    }
                } else {
                    let animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                    self.animatedStickerNode = animatedStickerNode
                    
                    let _ = (context.engine.stickers.loadedStickerPack(reference: .dice(dice.emoji), forceActualized: false)
                    |> deliverOnMainQueue).start(next: { stickerPack in
                        if let value = dice.value {
                            switch stickerPack {
                                case let .result(_, items, _):
                                    let item = items[Int(value)]

                                    animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: context.account, resource: item.file.resource), width: 120, height: 120, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                                default:
                                    break
                            }
                        }
                    })
                }
            case let .setProximityAlert(title, text, cancelled):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: cancelled ? "anim_proximity_cancelled" : "anim_proximity_set", colors: [:], scale: 0.45)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                if !text.isEmpty {
                    self.textNode.attributedText = attributedText
                }
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .invitedToVoiceChat(context, peer, text, action):
                self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 15.0))
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                
                self.avatarNode?.setPeer(context: context, theme: presentationData.theme, peer: peer, overrideImage: nil, emptyColor: presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: true)
                
                if let action = action {
                    displayUndo = true
                    undoText = action
                    self.originalRemainingSeconds = 5
                } else {
                    displayUndo = false
                    self.originalRemainingSeconds = 3
                }
            case let .audioRate(slowdown, text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: slowdown ? "anim_voicespeedstop" : "anim_voicespeed", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .forward(savedMessages, text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: savedMessages ? "anim_savedmessages" : "anim_forward", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .gigagroupConversion(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_gigagroup", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .linkRevoked(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_linkrevoked", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .voiceChatRecording(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_vcrecord", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .voiceChatFlag(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_vcflag", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .voiceChatCanSpeak(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_vcspeak", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .sticker(context, file, title, text, customUndoText, _):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                
                let stillStickerNode = TransformImageNode()
                
                self.stillStickerNode = stillStickerNode
                
                enum StickerThumbnailItem {
                    case still(TelegramMediaImageRepresentation)
                    case animated(EngineMediaResource)
                }
                
                var thumbnailItem: StickerThumbnailItem?
                var resourceReference: MediaResourceReference?
                
                if file.isAnimatedSticker {
                    thumbnailItem = .animated(EngineMediaResource(file.resource))
                    resourceReference = MediaResourceReference.media(media: .standalone(media: file), resource: file.resource)
                } else if let dimensions = file.dimensions, let resource = chatMessageStickerResource(file: file, small: true) as? TelegramMediaResource {
                    thumbnailItem = .still(TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false))
                    resourceReference = MediaResourceReference.media(media: .standalone(media: file), resource: resource)
                }
                
                var updatedImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var updatedFetchSignal: Signal<Never, EngineMediaResource.Fetch.Error>?
                
                let imageBoundingSize = CGSize(width: 34.0, height: 34.0)
                
                if let thumbnailItem = thumbnailItem {
                    switch thumbnailItem {
                    case let .still(representation):
                        let stillImageSize = representation.dimensions.cgSize.aspectFitted(imageBoundingSize)
                        self.stickerImageSize = stillImageSize
                        
                        updatedImageSignal = chatMessageStickerPackThumbnail(postbox: context.account.postbox, resource: representation.resource)
                    case let .animated(resource):
                        self.stickerImageSize = imageBoundingSize
                        
                        updatedImageSignal = chatMessageStickerPackThumbnail(postbox: context.account.postbox, resource: resource._asResource(), animated: true)
                    }
                    if let resourceReference = resourceReference {
                        updatedFetchSignal = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: resourceReference)
                        |> mapError { _ -> EngineMediaResource.Fetch.Error in
                            return .generic
                        }
                        |> ignoreValues
                    }
                } else {
                    updatedImageSignal = .single({ _ in return nil })
                    updatedFetchSignal = .complete()
                }
            
                if let title = title {
                    self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                } else {
                    self.titleNode.attributedText = nil
                }
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { contents in
                    return ("URL", contents)
                }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
            
                if text.contains("](") {
                    isUserInteractionEnabled = true
                }
            
                if let customUndoText = customUndoText {
                    undoText = customUndoText
                    displayUndo = true
                } else {
                    displayUndo = false
                }
                self.originalRemainingSeconds = isUserInteractionEnabled ? 5 : 3
            
                if let updatedFetchSignal = updatedFetchSignal {
                    self.fetchResourceDisposable = updatedFetchSignal.start()
                }
            
                if let updatedImageSignal = updatedImageSignal {
                    stillStickerNode.setSignal(updatedImageSignal)
                }
            
                if let thumbnailItem = thumbnailItem {
                    switch thumbnailItem {
                    case .still:
                        break
                    case let .animated(resource):
                        let animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                        self.animatedStickerNode = animatedStickerNode
                        animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: context.account, resource: resource._asResource(), isVideo: file.isVideoSticker), width: 80, height: 80, mode: .cached)
                    }
                }
            case let .copy(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_copy", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .mediaSaved(text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                
                let animatedStickerNode = DefaultAnimatedStickerNodeImpl()
                self.animatedStickerNode = animatedStickerNode
                
                animatedStickerNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "anim_savemedia"), width: 80, height: 80, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                animatedStickerNode.visibility = true
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                
                displayUndo = false
                self.originalRemainingSeconds = 3
            case let .inviteRequestSent(title, text):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_inviterequest", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .notificationSoundAdded(title, text, action):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_notificationsound", colors: [:], scale: 0.066)
                self.animatedStickerNode = nil
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                
            
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { contents in
                    return ("URL", contents)
                }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
            
                self.textNode.maximumNumberOfLines = 5
                displayUndo = false
                self.originalRemainingSeconds = 5
            
                if let action = action {
                    self.textNode.highlightAttributeAction = { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                            return NSAttributedString.Key(rawValue: "URL")
                        } else {
                            return nil
                        }
                    }
                    self.textNode.tapAttributeAction = { attributes, _ in
                        if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                            action()
                        }
                    }
                }
            case let .universal(animation, scale, colors, title, text, customUndoText):
                self.avatarNode = nil
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: animation, colors: colors, scale: scale)
                self.animatedStickerNode = nil
                if let title = title {
                    self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                } else {
                    self.titleNode.attributedText = nil
                }
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { contents in
                    return ("URL", contents)
                }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
            
            
                if text.contains("](") {
                    isUserInteractionEnabled = true
                }
                self.originalRemainingSeconds = isUserInteractionEnabled ? 5 : 3
            
                self.textNode.maximumNumberOfLines = 5
                
                if let customUndoText = customUndoText {
                    undoText = customUndoText
                    displayUndo = true
                } else {
                    displayUndo = false
                }
            case let .image(image, text):
                self.avatarNode = nil
                self.iconNode = ASImageNode()
                self.iconNode?.clipsToBounds = true
                self.iconNode?.contentMode = .scaleAspectFill
                self.iconNode?.image = image
                self.iconNode?.cornerRadius = 4.0
                self.iconImageSize = CGSize(width: 32.0, height: 32.0)
                self.iconCheckNode = nil
                self.animationNode = nil
                self.animatedStickerNode = nil
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = true
                self.originalRemainingSeconds = 5
            case let .peers(context, peers, title, text, customUndoText):
                self.avatarNode = nil
                let multiAvatarsNode = AnimatedAvatarSetNode()
                self.multiAvatarsNode = multiAvatarsNode
                let avatarsContext = AnimatedAvatarSetContext()
                self.multiAvatarsSize = multiAvatarsNode.update(context: context, content: avatarsContext.update(peers: peers, animated: false), itemSize: CGSize(width: 28.0, height: 28.0), animated: false, synchronousLoad: false)
                
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                self.animatedStickerNode = nil
                if let title = title {
                    self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                } else {
                    self.titleNode.attributedText = nil
                }
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: undoTextColor)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { contents in
                    return ("URL", contents)
                }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
            
                if text.contains("](") {
                    isUserInteractionEnabled = true
                }
                self.originalRemainingSeconds = isUserInteractionEnabled ? 5 : 3
            
                self.textNode.maximumNumberOfLines = 5
                
                if let customUndoText = customUndoText {
                    undoText = customUndoText
                    displayUndo = true
                } else {
                    displayUndo = false
                }
        }
        
        self.remainingSeconds = self.originalRemainingSeconds
        
        self.undoButtonTextNode = ImmediateTextNode()
        self.undoButtonTextNode.displaysAsynchronously = false
        self.undoButtonTextNode.attributedText = NSAttributedString(string: undoText, font: Font.regular(17.0), textColor: undoTextColor)
        
        self.undoButtonNode = HighlightTrackingButtonNode()
        
        self.panelNode = ASDisplayNode()
        if presentationData.theme.overallDarkAppearance {
            self.panelNode.backgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
        } else {
            self.panelNode.backgroundColor = .clear
        }
        self.panelNode.clipsToBounds = true
        self.panelNode.cornerRadius = 9.0
        
        self.panelWrapperNode = ASDisplayNode()
        
        self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        
        super.init()
        
        switch content {
        case .removedChat:
            self.panelWrapperNode.addSubnode(self.timerTextNode)
        case .archivedChat, .hidArchive, .revealedArchive, .autoDelete, .succeed, .emoji, .swipeToReply, .actionSucceeded, .stickersModified, .chatAddedToFolder, .chatRemovedFromFolder, .messagesUnpinned, .setProximityAlert, .invitedToVoiceChat, .linkCopied, .banned, .importedMessage, .audioRate, .forward, .gigagroupConversion, .linkRevoked, .voiceChatRecording, .voiceChatFlag, .voiceChatCanSpeak, .copy, .mediaSaved, .paymentSent, .image, .inviteRequestSent, .notificationSoundAdded, .universal, .peers:
            if self.textNode.tapAttributeAction != nil || displayUndo {
                self.isUserInteractionEnabled = true
            } else {
                self.isUserInteractionEnabled = false
            }
        case .sticker:
            self.isUserInteractionEnabled = displayUndo
        case .dice:
            self.panelWrapperNode.clipsToBounds = true
        case .info:
            if self.textNode.tapAttributeAction != nil || displayUndo {
                self.isUserInteractionEnabled = true
            } else {
                self.isUserInteractionEnabled = false
            }
        }
        if isUserInteractionEnabled {
            self.isUserInteractionEnabled = true
        }
        
        self.titleNode.isUserInteractionEnabled = false
        self.textNode.isUserInteractionEnabled = self.textNode.tapAttributeAction != nil
        self.iconNode?.isUserInteractionEnabled = false
        self.animationNode?.isUserInteractionEnabled = false
        self.iconCheckNode?.isUserInteractionEnabled = false
        self.avatarNode?.isUserInteractionEnabled = false
        self.multiAvatarsNode?.isUserInteractionEnabled = false
        self.slotMachineNode?.isUserInteractionEnabled = false
        self.animatedStickerNode?.isUserInteractionEnabled = false
        
        self.statusNode.flatMap(self.panelWrapperNode.addSubnode)
        self.iconNode.flatMap(self.panelWrapperNode.addSubnode)
        self.iconCheckNode.flatMap(self.panelWrapperNode.addSubnode)
        self.animationNode.flatMap(self.panelWrapperNode.addSubnode)
        self.stillStickerNode.flatMap(self.panelWrapperNode.addSubnode)
        self.animatedStickerNode.flatMap(self.panelWrapperNode.addSubnode)
        self.slotMachineNode.flatMap(self.panelWrapperNode.addSubnode)
        self.avatarNode.flatMap(self.panelWrapperNode.addSubnode)
        self.multiAvatarsNode.flatMap(self.panelWrapperNode.addSubnode)
        self.panelWrapperNode.addSubnode(self.buttonNode)
        self.panelWrapperNode.addSubnode(self.titleNode)
        self.panelWrapperNode.addSubnode(self.textNode)
        if displayUndo {
            self.panelWrapperNode.addSubnode(self.undoButtonTextNode)
            self.panelWrapperNode.addSubnode(self.undoButtonNode)
        }
        self.addSubnode(self.panelNode)
        self.addSubnode(self.panelWrapperNode)
        
        self.undoButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.undoButtonTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.undoButtonTextNode.alpha = 0.4
                } else {
                    strongSelf.undoButtonTextNode.alpha = 1.0
                    strongSelf.undoButtonTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.undoButtonNode.addTarget(self, action: #selector(self.undoButtonPressed), forControlEvents: .touchUpInside)
        
        self.animatedStickerNode?.started = { [weak self] in
            self?.stillStickerNode?.isHidden = true
        }
    }
    
    deinit {
        self.fetchResourceDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.panelNode.view.addSubview(self.effectView)
    }
    
    @objc private func buttonPressed() {
        if self.action(.info) {
            self.dismiss()
        }
    }
    
    @objc private func undoButtonPressed() {
        switch self.content {
        case let .sticker(_, _, _, _, _, customAction):
            if let customAction = customAction {
                customAction()
            } else {
                let _ = self.action(.undo)
            }
        default:
            let _ = self.action(.undo)
        }
        self.dismiss()
    }
    
    private func checkTimer() {
        let previousRemainingSeconds = Int(self.remainingSeconds)
        if self.timer != nil {
            self.remainingSeconds -= 0.5
        }
        if self.remainingSeconds <= 0.0 {
            let _ = self.action(.commit)
            self.dismiss()
        } else {
            if Int(self.remainingSeconds) != previousRemainingSeconds || (self.timerTextNode.attributedText?.string ?? "").isEmpty {
                if !self.timerTextNode.bounds.size.width.isZero, let snapshot = self.timerTextNode.view.snapshotContentTree() {
                    self.panelNode.view.insertSubview(snapshot, aboveSubview: self.timerTextNode.view)
                    snapshot.frame = self.timerTextNode.frame
                    self.timerTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                    self.timerTextNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -10.0), to: CGPoint(), duration: 0.12, removeOnCompletion: false, additive: true)
                    snapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false)
                    snapshot.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: 10.0), duration: 0.12, removeOnCompletion: false, additive: true, completion: { [weak snapshot] _ in
                        snapshot?.removeFromSuperview()
                    })
                }
                self.timerTextNode.attributedText = NSAttributedString(string: "\(Int(self.remainingSeconds))", font: Font.regular(16.0), textColor: .white)
                if let validLayout = self.validLayout {
                    self.containerLayoutUpdated(layout: validLayout, transition: .immediate)
                }
            }
            let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: false, completion: { [weak self] in
                self?.checkTimer()
            }, queue: .mainQueue())
            self.timer = timer
            timer.start()
        }
    }
    
    func renewWithCurrentContent() {
        self.timer?.invalidate()
        self.timer = nil
        self.remainingSeconds = self.originalRemainingSeconds
        self.checkTimer()
    }
    
    func updateContent(_ content: UndoOverlayContent) {
        self.content = content
        
        switch content {
            case let .image(image, text):
                self.iconNode?.image = image
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
            default:
                break
        }
        
        self.renewWithCurrentContent()
        
        if let validLayout = self.validLayout {
            self.containerLayoutUpdated(layout: validLayout, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil
        self.validLayout = layout
        
        var preferredSize: CGSize?
        var verticalOffset: CGFloat = 0.0
        if let animationNode = self.animationNode, let iconSize = animationNode.preferredSize() {
            if case .messagesUnpinned = self.content {
                let factor: CGFloat = 0.5
                preferredSize = CGSize(width: floor(iconSize.width * factor), height: floor(iconSize.height * factor))
            } else if case .linkCopied = self.content {
                let factor: CGFloat = 0.08
                preferredSize = CGSize(width: floor(iconSize.width * factor), height: floor(iconSize.height * factor))
            } else if case .banned = self.content {
                let factor: CGFloat = 0.08
                preferredSize = CGSize(width: floor(iconSize.width * factor), height: floor(iconSize.height * factor))
            } else if case .autoDelete = self.content {
                let factor: CGFloat = 0.07
                verticalOffset = -3.0
                preferredSize = CGSize(width: floor(iconSize.width * factor), height: floor(iconSize.height * factor))
            } else if case .paymentSent = self.content {
                let factor: CGFloat = 0.08
                preferredSize = CGSize(width: floor(iconSize.width * factor), height: floor(iconSize.height * factor))
            } else {
                preferredSize = iconSize
            }
        }
        
        var leftInset: CGFloat = 50.0
        if let iconSize = preferredSize {
            if iconSize.width > leftInset {
                leftInset = iconSize.width - 8.0
            }
        } else if let multiAvatarsSize = self.multiAvatarsSize {
            leftInset = 13.0 + multiAvatarsSize.width + 20.0
        }
        
        let rightInset: CGFloat = 16.0
        var contentHeight: CGFloat = 20.0
        
        let margin: CGFloat = 12.0
        
        let buttonTextSize = self.undoButtonTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        let buttonMinX: CGFloat
        if self.undoButtonNode.supernode != nil {
            buttonMinX = layout.size.width - layout.safeInsets.left - rightInset - buttonTextSize.width - margin * 2.0
        } else {
            buttonMinX = layout.size.width - layout.safeInsets.left - rightInset
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: buttonMinX - 8.0 - leftInset - layout.safeInsets.left - margin, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: buttonMinX - 8.0 - leftInset - layout.safeInsets.left - margin, height: .greatestFiniteMagnitude))
        
        if !titleSize.width.isZero {
            contentHeight += titleSize.height + 1.0
        }
        contentHeight += textSize.height
        
        contentHeight = max(49.0, contentHeight)
        
        var insets = layout.insets(options: [.input])
        switch self.placementPosition {
        case .top:
            break
        case .bottom:
            if self.elevatedLayout {
                insets.bottom += 49.0
            }
        }
        
        var panelFrame = CGRect(origin: CGPoint(x: margin + layout.safeInsets.left, y: layout.size.height - contentHeight - insets.bottom - margin), size: CGSize(width: layout.size.width - margin * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: contentHeight))
        var panelWrapperFrame = CGRect(origin: CGPoint(x: margin + layout.safeInsets.left, y: layout.size.height - contentHeight - insets.bottom - margin), size: CGSize(width: layout.size.width - margin * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: contentHeight))
        
        if case .top = self.placementPosition {
            panelFrame.origin.y = insets.top + margin
            panelWrapperFrame.origin.y = insets.top + margin
        }
        
        transition.updateFrame(node: self.panelNode, frame: panelFrame)
        transition.updateFrame(node: self.panelWrapperNode, frame: panelWrapperFrame)
        self.effectView.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width - margin * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: contentHeight)
        
        let buttonTextFrame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - rightInset - buttonTextSize.width - margin * 2.0, y: floor((contentHeight - buttonTextSize.height) / 2.0)), size: buttonTextSize)
        transition.updateFrame(node: self.undoButtonTextNode, frame: buttonTextFrame)
        
        let undoButtonFrame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - rightInset - buttonTextSize.width - 8.0 - margin * 2.0, y: 0.0), size: CGSize(width: layout.safeInsets.right + rightInset + buttonTextSize.width + 8.0 + margin, height: contentHeight))
        self.undoButtonNode.frame = undoButtonFrame
        
        self.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: undoButtonFrame.minX, height: contentHeight))
        
        var textContentHeight = textSize.height
        var textOffset: CGFloat = 0.0
        if !titleSize.width.isZero {
            textContentHeight += titleSize.height + 1.0
            textOffset += titleSize.height + 1.0
        }
        
        let textContentOrigin = floor((contentHeight - textContentHeight) / 2.0)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: textContentOrigin), size: titleSize))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: leftInset, y: textContentOrigin + textOffset), size: textSize))
        
        if let iconNode = self.iconNode {
            let iconSize: CGSize
            if let size = self.iconImageSize {
                iconSize = size
            } else if let size = iconNode.image?.size {
                iconSize = size
            } else {
                iconSize = CGSize()
            }
            
            let iconFrame = CGRect(origin: CGPoint(x: floor((leftInset - iconSize.width) / 2.0), y: floor((contentHeight - iconSize.height) / 2.0) + verticalOffset), size: iconSize)
            transition.updateFrame(node: iconNode, frame: iconFrame)
            
            if let iconCheckNode = self.iconCheckNode {
                let statusSize: CGFloat = iconCheckNode.frame.width
                var offset: CGFloat = 0.0
                if statusSize < 30.0 {
                    offset = 3.0
                }
                transition.updateFrame(node: iconCheckNode, frame: CGRect(origin: CGPoint(x: iconFrame.minX + floor((iconFrame.width - statusSize) / 2.0), y: iconFrame.minY + floor((iconFrame.height - statusSize) / 2.0) + offset), size: CGSize(width: statusSize, height: statusSize)))
            }
        }
        
        if let animationNode = self.animationNode, let iconSize = preferredSize {
            let iconFrame = CGRect(origin: CGPoint(x: floor((leftInset - iconSize.width) / 2.0), y: floor((contentHeight - iconSize.height) / 2.0) + verticalOffset), size: iconSize)
            transition.updateFrame(node: animationNode, frame: iconFrame)
        }
        
        if let stickerImageSize = self.stickerImageSize {
            let iconSize = stickerImageSize
            var iconFrame = CGRect(origin: CGPoint(x: floor((leftInset - iconSize.width) / 2.0), y: floor((contentHeight - iconSize.height) / 2.0)), size: iconSize)
            
            if let stickerOffset = self.stickerOffset {
                iconFrame = iconFrame.offsetBy(dx: stickerOffset.x, dy: stickerOffset.y)
            }
            
            if let stillStickerNode = self.stillStickerNode {
                let makeImageLayout = stillStickerNode.asyncLayout()
                let imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: stickerImageSize, boundingSize: stickerImageSize, intrinsicInsets: UIEdgeInsets()))
                let _ = imageApply()
                transition.updateFrame(node: stillStickerNode, frame: iconFrame)
            }
            
            if let animatedStickerNode = self.animatedStickerNode {
                animatedStickerNode.updateLayout(size: iconFrame.size)
                transition.updateFrame(node: animatedStickerNode, frame: iconFrame)
            } else if let slotMachineNode = self.slotMachineNode {
                transition.updateFrame(node: slotMachineNode, frame: iconFrame)
            }
        } else if let animatedStickerNode = self.animatedStickerNode {
            let iconSize = CGSize(width: 32.0, height: 32.0)
            let iconFrame = CGRect(origin: CGPoint(x: floor((leftInset - iconSize.width) / 2.0), y: floor((contentHeight - iconSize.height) / 2.0)), size: iconSize)
            animatedStickerNode.updateLayout(size: iconFrame.size)
            transition.updateFrame(node: animatedStickerNode, frame: iconFrame)
        } else if let slotMachineNode = self.slotMachineNode {
            let iconSize = CGSize(width: 32.0, height: 32.0)
            let iconFrame = CGRect(origin: CGPoint(x: floor((leftInset - iconSize.width) / 2.0), y: floor((contentHeight - iconSize.height) / 2.0)), size: iconSize)
            transition.updateFrame(node: slotMachineNode, frame: iconFrame)
        }
   
        let timerTextSize = self.timerTextNode.updateLayout(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.timerTextNode, frame: CGRect(origin: CGPoint(x: floor((leftInset - timerTextSize.width) / 2.0), y: floor((contentHeight - timerTextSize.height) / 2.0)), size: timerTextSize))

        if let statusNode = self.statusNode {
            let statusSize: CGFloat = 30.0
            transition.updateFrame(node: statusNode, frame: CGRect(origin: CGPoint(x: floor((leftInset - statusSize) / 2.0), y: floor((contentHeight - statusSize) / 2.0)), size: CGSize(width: statusSize, height: statusSize)))
            if firstLayout {
                statusNode.transitionToState(.secretTimeout(color: .white, icon: nil, beginTime: CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970, timeout: Double(self.remainingSeconds), sparks: false), completion: {})
            }
        }
        
        if let avatarNode = self.avatarNode {
            let avatarSize: CGFloat = 30.0
            transition.updateFrame(node: avatarNode, frame: CGRect(origin: CGPoint(x: floor((leftInset - avatarSize) / 2.0), y: floor((contentHeight - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize)))
        }
        
        if let multiAvatarsNode = self.multiAvatarsNode, let multiAvatarsSize = self.multiAvatarsSize {
            let avatarsFrame = CGRect(origin: CGPoint(x: 13.0, y: floor((contentHeight - multiAvatarsSize.height) / 2.0) + verticalOffset), size: multiAvatarsSize)
            transition.updateFrame(node: multiAvatarsNode, frame: avatarsFrame)
        }
    }
    
    func animateIn(asReplacement: Bool) {
        if asReplacement {
            let offset: CGFloat
            switch self.placementPosition {
            case .top:
                offset = -self.panelWrapperNode.frame.maxY
            case.bottom:
                offset = self.bounds.height - self.panelWrapperNode.frame.minY
            }
            
            self.panelWrapperNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: 0.35, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: nil)
            self.panelNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: 0.35, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: nil)
        } else {
            self.panelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.panelWrapperNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        
        if let iconCheckNode = self.iconCheckNode, self.iconNode != nil {
            Queue.mainQueue().after(0.2, { [weak iconCheckNode] in
                iconCheckNode?.transitionToState(.check(self.animationBackgroundColor), completion: {})
            })
        }
        
        if let animationNode = self.animationNode {
            Queue.mainQueue().after(0.2, { [weak animationNode] in
                animationNode?.play()
            })
        }
        
        self.animatedStickerNode?.visibility = true
        
        self.checkTimer()
    }
    
    var dismissed = false
    func animateOut(completion: @escaping () -> Void) {
        guard !self.dismissed else {
            return
        }
        self.dismissed = true
        self.panelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { _ in })
        self.panelWrapperNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false) { _ in
            completion()
        }
    }
    
    func animateOutWithReplacement(completion: @escaping () -> Void) {
        self.panelWrapperNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.3, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.panelWrapperNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.panelNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.3, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.panelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.panelNode.frame.insetBy(dx: -60.0, dy: 0.0).contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
