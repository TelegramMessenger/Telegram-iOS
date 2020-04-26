import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import RadialStatusNode
import AppBundle
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AnimationUI
import SyncCore
import Postbox
import TelegramCore
import StickerResources

final class UndoOverlayControllerNode: ViewControllerTracingNode {
    private let elevatedLayout: Bool
    private var statusNode: RadialStatusNode?
    private let timerTextNode: ImmediateTextNode
    private let iconNode: ASImageNode?
    private let iconCheckNode: RadialStatusNode?
    private let animationNode: AnimationNode?
    private var animatedStickerNode: AnimatedStickerNode?
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
    
    private let effectView: UIView
    
    private let animationBackgroundColor: UIColor
        
    private var originalRemainingSeconds: Int
    private var remainingSeconds: Int
    private var timer: SwiftSignalKit.Timer?
    
    private var validLayout: ContainerViewLayout?
    
    private var fetchResourceDisposable: Disposable?
    
    init(presentationData: PresentationData, content: UndoOverlayContent, elevatedLayout: Bool, action: @escaping (UndoOverlayAction) -> Bool, dismiss: @escaping () -> Void) {
        self.elevatedLayout = elevatedLayout
        
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
        
        if presentationData.theme.overallDarkAppearance {
            self.animationBackgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
        } else {
            self.animationBackgroundColor = UIColor(rgb: 0x474747)
        }
        
        switch content {
            case let .removedChat(text):
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                self.animatedStickerNode = nil
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = true
                self.originalRemainingSeconds = 5
                self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
            case let .archivedChat(_, title, text, undo):
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
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_archiveswipe", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = undo
                self.originalRemainingSeconds = 3
            case let .revealedArchive(title, text, undo):
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_infotip", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                displayUndo = undo
                self.originalRemainingSeconds = 3
            case let .succeed(text):
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_success", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .info(text):
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_infotip", colors: ["info1.info1.stroke": self.animationBackgroundColor, "info2.info2.Fill": self.animationBackgroundColor], scale: 1.0)
                self.animatedStickerNode = nil
            
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = max(5, min(8, text.count / 14))
            case let .actionSucceeded(title, text, cancel):
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
            case let .emoji(path, text):
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                self.animatedStickerNode = AnimatedStickerNode()
                self.animatedStickerNode?.visibility = true
                self.animatedStickerNode?.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 100, height: 100, playbackMode: .once, mode: .direct)
                
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
                self.textNode.attributedText = attributedText
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .swipeToReply(title, text):
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = AnimationNode(animation: "anim_swipereply", colors: [:], scale: 1.0)
                self.animatedStickerNode = nil
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
                self.textNode.maximumNumberOfLines = 2
                displayUndo = false
                self.originalRemainingSeconds = 5
            case let .stickersModified(title, text, undo, info, topItem, account):
                self.iconNode = nil
                self.iconCheckNode = nil
                self.animationNode = nil
                
                let stillStickerNode = TransformImageNode()
                
                self.stillStickerNode = stillStickerNode
                
                enum StickerPackThumbnailItem {
                    case still(TelegramMediaImageRepresentation)
                    case animated(MediaResource)
                }
                
                var thumbnailItem: StickerPackThumbnailItem?
                var resourceReference: MediaResourceReference?
                
                if let thumbnail = info.thumbnail {
                    if info.flags.contains(.isAnimated) {
                        thumbnailItem = .animated(thumbnail.resource)
                        resourceReference = MediaResourceReference.stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource)
                    } else {
                        thumbnailItem = .still(thumbnail)
                        resourceReference = MediaResourceReference.stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource)
                    }
                } else if let item = topItem as? StickerPackItem {
                    if item.file.isAnimatedSticker {
                        thumbnailItem = .animated(item.file.resource)
                        resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: item.file.resource)
                    } else if let dimensions = item.file.dimensions, let resource = chatMessageStickerResource(file: item.file, small: true) as? TelegramMediaResource {
                        thumbnailItem = .still(TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource))
                        resourceReference = MediaResourceReference.media(media: .standalone(media: item.file), resource: resource)
                    }
                }
                
                var updatedImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var updatedFetchSignal: Signal<FetchResourceSourceType, FetchResourceError>?
                
                let imageBoundingSize = CGSize(width: 34.0, height: 34.0)
                
                if let thumbnailItem = thumbnailItem {
                    switch thumbnailItem {
                    case let .still(representation):
                        let stillImageSize = representation.dimensions.cgSize.aspectFitted(imageBoundingSize)
                        self.stickerImageSize = stillImageSize
                        
                        updatedImageSignal = chatMessageStickerPackThumbnail(postbox: account.postbox, resource: representation.resource)
                    case let .animated(resource):
                        self.stickerImageSize = imageBoundingSize
                        
                        updatedImageSignal = chatMessageStickerPackThumbnail(postbox: account.postbox, resource: resource, animated: true)
                    }
                    if let resourceReference = resourceReference {
                        updatedFetchSignal = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: resourceReference)
                    }
                } else {
                    updatedImageSignal = .single({ _ in return nil })
                    updatedFetchSignal = .complete()
                }
                
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(14.0), textColor: .white)
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
                let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .natural)
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
                    case let .animated(resource):
                        let animatedStickerNode = AnimatedStickerNode()
                        self.animatedStickerNode = animatedStickerNode
                        animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: account, resource: resource), width: 80, height: 80, mode: .cached)
                    }
                }
            case let .dice(dice, account, text, action):
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
                
                let animatedStickerNode = AnimatedStickerNode()
                self.animatedStickerNode = animatedStickerNode
                
                let _ = (loadedStickerPack(postbox: account.postbox, network: account.network, reference: .dice(dice.emoji), forceActualized: false)
                |> deliverOnMainQueue).start(next: { stickerPack in
                    if let value = dice.value {
                        switch stickerPack {
                            case let .result(_, items, _):
                                let item = items[Int(value)]
                                if let item = item as? StickerPackItem {
                                    animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: account, resource: item.file.resource), width: 120, height: 120, playbackMode: .once, mode: .direct)
                                }
                            default:
                                break
                        }
                    }
                })
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
        case .archivedChat, .hidArchive, .revealedArchive, .succeed, .emoji, .swipeToReply, .actionSucceeded, .stickersModified:
            break
        case .dice:
            self.panelWrapperNode.clipsToBounds = true
        case .info:
            self.isUserInteractionEnabled = false
        }
        self.statusNode.flatMap(self.panelWrapperNode.addSubnode)
        self.iconNode.flatMap(self.panelWrapperNode.addSubnode)
        self.iconCheckNode.flatMap(self.panelWrapperNode.addSubnode)
        self.animationNode.flatMap(self.panelWrapperNode.addSubnode)
        self.stillStickerNode.flatMap(self.panelWrapperNode.addSubnode)
        self.animatedStickerNode.flatMap(self.panelWrapperNode.addSubnode)
        self.panelWrapperNode.addSubnode(self.titleNode)
        self.panelWrapperNode.addSubnode(self.textNode)
        self.panelWrapperNode.addSubnode(self.buttonNode)
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
        if self.panelNode.backgroundColor == .clear {
            self.panelNode.view.addSubview(self.effectView)
        }
    }
    
    @objc private func buttonPressed() {
        if self.action(.info) {
            self.dismiss()
        }
    }
    
    @objc private func undoButtonPressed() {
        let _ = self.action(.undo)
        self.dismiss()
    }
    
    private func checkTimer() {
        if self.timer != nil {
            self.remainingSeconds -= 1
        }
        if self.remainingSeconds == 0 {
            let _ = self.action(.commit)
            self.dismiss()
        } else {
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
            self.timerTextNode.attributedText = NSAttributedString(string: "\(self.remainingSeconds)", font: Font.regular(16.0), textColor: .white)
            if let validLayout = self.validLayout {
                self.containerLayoutUpdated(layout: validLayout, transition: .immediate)
            }
            let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
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
    
    func containerLayoutUpdated(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil
        self.validLayout = layout
        
        var leftInset: CGFloat = 50.0
        if let animationNode = self.animationNode, let iconSize = animationNode.preferredSize() {
            if iconSize.width > leftInset {
                leftInset = iconSize.width - 8.0
            }
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
        if self.elevatedLayout {
            insets.bottom += 49.0
        }
        
        let panelFrame = CGRect(origin: CGPoint(x: margin + layout.safeInsets.left, y: layout.size.height - contentHeight - insets.bottom - margin), size: CGSize(width: layout.size.width - margin * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: contentHeight))
        let panelWrapperFrame = CGRect(origin: CGPoint(x: margin + layout.safeInsets.left, y: layout.size.height - contentHeight - insets.bottom - margin), size: CGSize(width: layout.size.width - margin * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: contentHeight))
        transition.updateFrame(node: self.panelNode, frame: panelFrame)
        transition.updateFrame(node: self.panelWrapperNode, frame: panelWrapperFrame)
        self.effectView.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width - margin * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: contentHeight)
        
        let buttonTextFrame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - rightInset - buttonTextSize.width - margin * 2.0, y: floor((contentHeight - buttonTextSize.height) / 2.0)), size: buttonTextSize)
        transition.updateFrame(node: self.undoButtonTextNode, frame: buttonTextFrame)
        
        let undoButtonFrame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - rightInset - buttonTextSize.width - 8.0 - margin * 2.0, y: 0.0), size: CGSize(width: layout.safeInsets.right + rightInset + buttonTextSize.width + 8.0 + margin, height: contentHeight))
        self.undoButtonNode.frame = undoButtonFrame
        
        self.buttonNode.frame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: 0.0), size: CGSize(width: undoButtonFrame.minX - layout.safeInsets.left, height: contentHeight))
        
        var textContentHeight = textSize.height
        var textOffset: CGFloat = 0.0
        if !titleSize.width.isZero {
            textContentHeight += titleSize.height + 1.0
            textOffset += titleSize.height + 1.0
        }
        
        let textContentOrigin = floor((contentHeight - textContentHeight) / 2.0)
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: textContentOrigin), size: titleSize))
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: leftInset, y: textContentOrigin + textOffset), size: textSize))
        
        if let iconNode = self.iconNode, let iconSize = iconNode.image?.size {
            let iconFrame = CGRect(origin: CGPoint(x: floor((leftInset - iconSize.width) / 2.0), y: floor((contentHeight - iconSize.height) / 2.0)), size: iconSize)
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
        
        if let animationNode = self.animationNode, let iconSize = animationNode.preferredSize() {
            let iconFrame = CGRect(origin: CGPoint(x: floor((leftInset - iconSize.width) / 2.0), y: floor((contentHeight - iconSize.height) / 2.0)), size: iconSize)
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
            }
        } else if let animatedStickerNode = self.animatedStickerNode {
            let iconSize = CGSize(width: 32.0, height: 32.0)
            let iconFrame = CGRect(origin: CGPoint(x: floor((leftInset - iconSize.width) / 2.0), y: floor((contentHeight - iconSize.height) / 2.0)), size: iconSize)
            animatedStickerNode.updateLayout(size: iconFrame.size)
            transition.updateFrame(node: animatedStickerNode, frame: iconFrame)
        }
        
        let timerTextSize = self.timerTextNode.updateLayout(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.timerTextNode, frame: CGRect(origin: CGPoint(x: floor((leftInset - timerTextSize.width) / 2.0), y: floor((contentHeight - timerTextSize.height) / 2.0)), size: timerTextSize))
        let statusSize: CGFloat = 30.0
        if let statusNode = self.statusNode {
            transition.updateFrame(node: statusNode, frame: CGRect(origin: CGPoint(x: floor((leftInset - statusSize) / 2.0), y: floor((contentHeight - statusSize) / 2.0)), size: CGSize(width: statusSize, height: statusSize)))
            if firstLayout {
                statusNode.transitionToState(.secretTimeout(color: .white, icon: nil, beginTime: CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970, timeout: Double(self.remainingSeconds), sparks: false), completion: {})
            }
        }
    }
    
    func animateIn(asReplacement: Bool) {
        if asReplacement {
            let offset = self.bounds.height - self.panelWrapperNode.frame.minY
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
