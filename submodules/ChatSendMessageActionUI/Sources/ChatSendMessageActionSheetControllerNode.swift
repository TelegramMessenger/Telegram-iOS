import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import ContextUI

private let leftInset: CGFloat = 16.0
private let rightInset: CGFloat = 16.0

private enum ChatSendMessageActionIcon {
    case sendWithoutSound
    case schedule
    
    func image(theme: PresentationTheme) -> UIImage? {
        let imageName: String
        switch self {
            case .sendWithoutSound:
                imageName = "Chat/Input/Menu/SilentIcon"
            case .schedule:
                imageName = "Chat/Input/Menu/ScheduleIcon"
        }
        return generateTintedImage(image: UIImage(bundleImageName: imageName), color: theme.contextMenu.primaryColor)
    }
}

private final class ActionSheetItemNode: ASDisplayNode {
    private let title: String
    private let icon: ChatSendMessageActionIcon
    let action: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    
    private var maxWidth: CGFloat?
    
    init(theme: PresentationTheme, title: String, icon: ChatSendMessageActionIcon, hasSeparator: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.contextMenu.itemSeparatorColor
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        self.backgroundNode.backgroundColor = theme.contextMenu.itemBackgroundColor
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        self.highlightedBackgroundNode.backgroundColor = theme.contextMenu.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = title
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isAccessibilityElement = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(17.0), textColor: theme.contextMenu.primaryColor)
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.iconNode = ASImageNode()
        self.iconNode.image = icon.image(theme: theme)
        self.iconNode.contentMode = .center
        self.iconNode.isAccessibilityElement = false
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.buttonNode)
        if hasSeparator {
            self.addSubnode(self.separatorNode)
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                strongSelf.setHighlighted(highlighted, animated: true)
            }
        }
    }
    
    func setHighlighted(_ highlighted: Bool, animated: Bool) {
        if highlighted == (self.highlightedBackgroundNode.alpha == 1.0) {
            return
        }
        
        if highlighted {
            self.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            self.highlightedBackgroundNode.alpha = 0.0
            if animated {
                self.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.separatorNode.backgroundColor = theme.contextMenu.itemSeparatorColor
        self.backgroundNode.backgroundColor = theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode.backgroundColor = theme.contextMenu.itemHighlightedBackgroundColor
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.regular(17.0), textColor: theme.contextMenu.primaryColor)
        self.iconNode.image = self.icon.image(theme: theme)
        
        if let maxWidth = self.maxWidth {
            let _ = self.titleNode.updateLayout(CGSize(width: maxWidth - leftInset - rightInset, height: .greatestFiniteMagnitude))
        }
    }
    
    func updateLayout(maxWidth: CGFloat) -> (CGFloat, CGFloat, (CGFloat) -> Void) {
        self.maxWidth = maxWidth
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: maxWidth - leftInset - rightInset, height: .greatestFiniteMagnitude))
        let height: CGFloat = 44.0
        
        return (titleSize.width + leftInset + rightInset, height, { width in
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            
            if let image = self.iconNode.image {
                self.iconNode.frame = CGRect(origin: CGPoint(x: width - image.size.width - 12.0, y: floor((height - image.size.height) / 2.0)), size: image.size)
            }
            
            self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: height - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel))
            self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
            self.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
        })
    }
    
    @objc private func buttonPressed() {
        self.buttonNode.isUserInteractionEnabled = false
        self.action()
    }
}

final class ChatSendMessageActionSheetControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let sourceSendButton: ASDisplayNode
    private let textFieldFrame: CGRect
    private let textInputNode: EditableTextNode
    private let attachment: Bool
    private let forwardedCount: Int?
    
    private let send: (() -> Void)?
    private let cancel: (() -> Void)?
    
    private let effectView: UIVisualEffectView
    private let dimNode: ASDisplayNode
    
    private let contentContainerNode: ASDisplayNode
    private let contentNodes: [ActionSheetItemNode]
    private let sendButtonNode: HighlightableButtonNode
    
    private let messageClipNode: ASDisplayNode
    private let messageBackgroundNode: ASImageNode
    private let fromMessageTextNode: EditableTextNode
    private let toMessageTextNode: EditableTextNode
    private let scrollNode: ASScrollNode
    
    private var validLayout: ContainerViewLayout?
    
    private var sendButtonFrame: CGRect {
        return self.sourceSendButton.view.convert(self.sourceSendButton.bounds, to: nil)
    }
    
    private var animateInputField = false
    
    init(context: AccountContext, presentationData: PresentationData, reminders: Bool, gesture: ContextGesture, sourceSendButton: ASDisplayNode, textInputNode: EditableTextNode, attachment: Bool, forwardedCount: Int?, send: (() -> Void)?, sendSilently: (() -> Void)?, schedule: (() -> Void)?, cancel: (() -> Void)?) {
        self.context = context
        self.presentationData = presentationData
        self.sourceSendButton = sourceSendButton
        self.textFieldFrame = textInputNode.convert(textInputNode.bounds, to: nil)
        self.textInputNode = textInputNode
        self.attachment = attachment
        self.forwardedCount = forwardedCount
        
        self.send = send
        self.cancel = cancel
                
        self.effectView = UIVisualEffectView()
        if #available(iOS 9.0, *) {
        } else {
            if self.presentationData.theme.rootController.keyboardColor == .dark {
                self.effectView.effect = UIBlurEffect(style: .dark)
            } else {
                self.effectView.effect = UIBlurEffect(style: .light)
            }
            self.effectView.alpha = 0.0
        }
        
        self.dimNode = ASDisplayNode()
        self.dimNode.alpha = 1.0
        self.dimNode.backgroundColor = self.presentationData.theme.contextMenu.dimColor
        
        self.sendButtonNode = HighlightableButtonNode()
        self.sendButtonNode.imageNode.displayWithoutProcessing = false
        self.sendButtonNode.imageNode.displaysAsynchronously = false
        self.sendButtonNode.accessibilityLabel = self.presentationData.strings.MediaPicker_Send
        
        self.messageClipNode = ASDisplayNode()
        self.messageClipNode.clipsToBounds = true
        self.messageClipNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        self.messageBackgroundNode = ASImageNode()
        self.messageBackgroundNode.isUserInteractionEnabled = true
        self.fromMessageTextNode = EditableTextNode()
        self.fromMessageTextNode.isUserInteractionEnabled = false
        self.toMessageTextNode = EditableTextNode()
        self.toMessageTextNode.alpha = 0.0
        self.toMessageTextNode.isUserInteractionEnabled = false
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.backgroundColor = self.presentationData.theme.contextMenu.backgroundColor
        self.contentContainerNode.cornerRadius = 14.0
        self.contentContainerNode.clipsToBounds = true
        
        var contentNodes: [ActionSheetItemNode] = []
        if !reminders {
            contentNodes.append(ActionSheetItemNode(theme: self.presentationData.theme, title: self.presentationData.strings.Conversation_SendMessage_SendSilently, icon: .sendWithoutSound, hasSeparator: true, action: {
                sendSilently?()
            }))
        }
        if let _ = schedule {
            contentNodes.append(ActionSheetItemNode(theme: self.presentationData.theme, title: reminders ? self.presentationData.strings.Conversation_SendMessage_SetReminder: self.presentationData.strings.Conversation_SendMessage_ScheduleMessage, icon: .schedule, hasSeparator: false, action: {
                schedule?()
            }))
        }
        self.contentNodes = contentNodes
        
        super.init()
                        
        self.sendButtonNode.addTarget(self, action: #selector(self.sendButtonPressed), forControlEvents: .touchUpInside)
        
        if let attributedText = textInputNode.attributedText, !attributedText.string.isEmpty {
            self.animateInputField = true
            self.fromMessageTextNode.attributedText = attributedText
            
            if let toAttributedText = self.fromMessageTextNode.attributedText?.mutableCopy() as? NSMutableAttributedString {
                toAttributedText.addAttribute(NSAttributedString.Key.foregroundColor, value: self.presentationData.theme.chat.message.outgoing.primaryTextColor, range: NSMakeRange(0, (toAttributedText.string as NSString).length))
                self.toMessageTextNode.attributedText = toAttributedText
            }
        } else {
            if let _ = forwardedCount {
                self.animateInputField = true
            }
            self.fromMessageTextNode.attributedText = NSAttributedString(string: self.attachment ? self.presentationData.strings.MediaPicker_AddCaption : self.presentationData.strings.Conversation_InputTextPlaceholder, attributes: [NSAttributedString.Key.foregroundColor: self.presentationData.theme.chat.inputPanel.inputPlaceholderColor, NSAttributedString.Key.font: Font.regular(self.presentationData.chatFontSize.baseDisplaySize)])
        
            self.toMessageTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.ForwardedMessages(Int32(forwardedCount ?? 0)), attributes: [NSAttributedString.Key.foregroundColor: self.presentationData.theme.chat.message.outgoing.primaryTextColor, NSAttributedString.Key.font: Font.regular(self.presentationData.chatFontSize.baseDisplaySize)])
        }
        self.messageBackgroundNode.contentMode = .scaleToFill
        
        let outgoing: PresentationThemeBubbleColorComponents = self.presentationData.chatWallpaper.isEmpty ? self.presentationData.theme.chat.message.outgoing.bubble.withoutWallpaper : self.presentationData.theme.chat.message.outgoing.bubble.withWallpaper
        
        let maxCornerRadius = self.presentationData.chatBubbleCorners.mainRadius
        self.messageBackgroundNode.image = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: maxCornerRadius, incoming: false, fillColor: outgoing.fill.last ?? outgoing.fill[0], strokeColor: outgoing.fill.count > 1 ? outgoing.stroke : .clear, neighbors: .none, theme: self.presentationData.theme.chat, wallpaper: self.presentationData.chatWallpaper, knockout: false)
        
        self.view.addSubview(self.effectView)
        self.addSubnode(self.dimNode)
        
        self.addSubnode(self.contentContainerNode)
        self.addSubnode(self.scrollNode)
        
        self.addSubnode(self.sendButtonNode)
        self.scrollNode.addSubnode(self.messageClipNode)
        self.messageClipNode.addSubnode(self.messageBackgroundNode)
        self.messageClipNode.addSubnode(self.fromMessageTextNode)
        self.messageClipNode.addSubnode(self.toMessageTextNode)
        
        self.contentNodes.forEach(self.contentContainerNode.addSubnode)
        
        gesture.externalUpdated = { [weak self] view, location in
            guard let strongSelf = self else {
                return
            }
            for contentNode in strongSelf.contentNodes {
                let localPoint = contentNode.view.convert(location, from: view)
                if contentNode.bounds.contains(localPoint) {
                    contentNode.setHighlighted(true, animated: false)
                } else {
                    contentNode.setHighlighted(false, animated: false)
                }
            }
        }
        
        gesture.externalEnded = { [weak self] viewAndLocation in
            guard let strongSelf = self else {
                return
            }
            for contentNode in strongSelf.contentNodes {
                if let (view, location) = viewAndLocation {
                    let localPoint = contentNode.view.convert(location, from: view)
                    if contentNode.bounds.contains(localPoint) {
                        contentNode.action()
                    } else {
                        contentNode.setHighlighted(false, animated: false)
                    }
                } else {
                    contentNode.setHighlighted(false, animated: false)
                }
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result != self.scrollNode.view {
            return result
        } else {
            return self.dimNode.view
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.delegate = self
        self.scrollNode.view.alwaysBounceVertical = true
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        if let snapshotView = self.sourceSendButton.view.snapshotView(afterScreenUpdates: false) {
            self.sendButtonNode.view.addSubview(snapshotView)
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        guard presentationData.theme !== self.presentationData.theme else {
            return
        }
        self.presentationData = presentationData
        
        if #available(iOS 9.0, *) {
        } else {
            if self.presentationData.theme.rootController.keyboardColor == .dark {
                self.effectView.effect = UIBlurEffect(style: .dark)
            } else {
                self.effectView.effect = UIBlurEffect(style: .light)
            }
        }
        
        self.dimNode.backgroundColor = presentationData.theme.contextMenu.dimColor
        
        self.contentContainerNode.backgroundColor = self.presentationData.theme.contextMenu.backgroundColor
        
        if let toAttributedText = self.textInputNode.attributedText?.mutableCopy() as? NSMutableAttributedString {
            toAttributedText.addAttribute(NSAttributedString.Key.foregroundColor, value: self.presentationData.theme.chat.message.outgoing.primaryTextColor, range: NSMakeRange(0, (toAttributedText.string as NSString).length))
            self.toMessageTextNode.attributedText = toAttributedText
        }
        
        let outgoing: PresentationThemeBubbleColorComponents = self.presentationData.chatWallpaper.isEmpty ? self.presentationData.theme.chat.message.outgoing.bubble.withoutWallpaper : self.presentationData.theme.chat.message.outgoing.bubble.withWallpaper
        let maxCornerRadius = self.presentationData.chatBubbleCorners.mainRadius
        self.messageBackgroundNode.image = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: maxCornerRadius, incoming: false, fillColor: outgoing.fill.last ?? outgoing.fill[0], strokeColor: outgoing.fill.count > 1 ? outgoing.stroke : .clear, neighbors: .none, theme: self.presentationData.theme.chat, wallpaper: self.presentationData.chatWallpaper, knockout: false)
        
        for node in self.contentNodes {
            node.updateTheme(presentationData.theme)
        }
    }
    
    func animateIn() {
        guard let layout = self.validLayout else {
            return
        }
        
        self.textInputNode.textView.setContentOffset(self.textInputNode.textView.contentOffset, animated: false)
        
        UIView.animate(withDuration: 0.2, animations: {
            if #available(iOS 9.0, *) {
                self.effectView.effect = makeCustomZoomBlurEffect(isLight: !self.presentationData.theme.overallDarkAppearance)
            } else {
                self.effectView.alpha = 1.0
            }
        }, completion: { _ in })
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.contentContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.messageBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        self.sourceSendButton.isHidden = true
        if self.animateInputField {
            self.fromMessageTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.toMessageTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, removeOnCompletion: false)
            self.textInputNode.isHidden = true
        } else {
            self.messageBackgroundNode.isHidden = true
            self.fromMessageTextNode.isHidden = true
            self.toMessageTextNode.isHidden = true
        }
        
        let duration = 0.4
        self.sendButtonNode.layer.animateScale(from: 0.75, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.linear.rawValue)
        self.sendButtonNode.layer.animatePosition(from: self.sendButtonFrame.center, to: self.sendButtonNode.position, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        
        var initialWidth = self.textFieldFrame.width + 32.0
        if self.textInputNode.textView.attributedText.string.isEmpty {
            initialWidth = ceil(layout.size.width - self.textFieldFrame.origin.x - self.sendButtonFrame.width - layout.safeInsets.left - layout.safeInsets.right + 21.0)
        }
        
        let fromFrame = CGRect(origin: CGPoint(), size: CGSize(width: initialWidth, height: self.textFieldFrame.height + 2.0))
        let delta = (fromFrame.height - self.messageClipNode.bounds.height) / 2.0
        
        let inputHeight = layout.inputHeight ?? 0.0
        var clipDelta = delta
        if inputHeight.isZero || layout.isNonExclusive {
            clipDelta -= self.contentContainerNode.frame.height + 16.0
        }
        
        self.messageClipNode.layer.animateBounds(from: fromFrame, to: self.messageClipNode.bounds, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        self.messageClipNode.layer.animatePosition(from: CGPoint(x: (self.messageClipNode.bounds.width - initialWidth) / 2.0, y: clipDelta), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.insertSubnode(strongSelf.contentContainerNode, aboveSubnode: strongSelf.scrollNode)
            }
        })
        
        self.messageBackgroundNode.layer.animateBounds(from: fromFrame, to: self.messageBackgroundNode.bounds, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        self.messageBackgroundNode.layer.animatePosition(from: CGPoint(x: (initialWidth - self.messageClipNode.bounds.width) / 2.0, y: delta), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
       
        var textXOffset: CGFloat = 0.0
        let textYOffset = self.textInputNode.textView.contentSize.height - self.textInputNode.textView.contentOffset.y - self.textInputNode.textView.frame.height
        if self.textInputNode.textView.numberOfLines == 1 && self.textInputNode.isRTL {
            textXOffset = initialWidth - self.messageClipNode.bounds.width
        }
        self.fromMessageTextNode.layer.animatePosition(from: CGPoint(x: textXOffset, y: delta * 2.0 + textYOffset), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        self.toMessageTextNode.layer.animatePosition(from: CGPoint(x: textXOffset, y: delta * 2.0 + textYOffset), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        let contentOffset = CGPoint(x:  self.sendButtonFrame.midX - self.contentContainerNode.frame.midX, y:  self.sendButtonFrame.midY - self.contentContainerNode.frame.midY)
    
        let springDuration: Double = 0.42
        let springDamping: CGFloat = 104.0
        self.contentContainerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
        self.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: contentOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
    }
    
    func animateOut(cancel: Bool, completion: @escaping () -> Void) {
        guard let layout = self.validLayout else {
            return
        }
        
        self.isUserInteractionEnabled = false
        
        self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
        
        var completedEffect = false
        var completedButton = false
        var completedBubble = false
        var completedAlpha = false
        
        let intermediateCompletion: () -> Void = { [weak self] in
            if completedEffect && completedButton && completedBubble && completedAlpha {
                self?.textInputNode.isHidden = false
                self?.sourceSendButton.isHidden = false
                completion()
            }
        }
        
        UIView.animate(withDuration: 0.4, animations: {
            if #available(iOS 9.0, *) {
                self.effectView.effect = nil
            } else {
                self.effectView.alpha = 0.0
            }
        }, completion: { _ in
            completedEffect = true
            intermediateCompletion()
        })
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in })
        
        if self.animateInputField {
            if cancel {
                self.fromMessageTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, delay: 0.15, removeOnCompletion: false)
                self.toMessageTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, delay: 0.15, removeOnCompletion: false)
                self.messageBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, delay: 0.15, removeOnCompletion: false, completion: { _ in
                    completedAlpha = true
                    intermediateCompletion()
                })
            } else {
                self.textInputNode.isHidden = false
                self.messageClipNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                    completedAlpha = true
                    intermediateCompletion()
                })
            }
        } else {
            completedAlpha = true
        }
        
        let duration = 0.4
        
        self.sendButtonNode.layer.animatePosition(from: self.sendButtonNode.position, to: self.sendButtonFrame.center, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completedButton = true
            intermediateCompletion()
        })
        
        if !cancel {
            self.sourceSendButton.isHidden = false
            self.sendButtonNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false)
            self.sendButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false)
        }
        
        var initialWidth = self.textFieldFrame.width + 32.0
        if self.textInputNode.textView.attributedText.string.isEmpty {
            initialWidth = ceil(layout.size.width - self.textFieldFrame.origin.x - self.sendButtonFrame.width - layout.safeInsets.left - layout.safeInsets.right + 21.0)
        }
        
        let toFrame = CGRect(origin: CGPoint(), size: CGSize(width: initialWidth, height: self.textFieldFrame.height + 1.0))
        let delta = (toFrame.height - self.messageClipNode.bounds.height) / 2.0
                
        if cancel && self.animateInputField {
            let inputHeight = layout.inputHeight ?? 0.0
            var clipDelta = delta
            if inputHeight.isZero || layout.isNonExclusive {
                clipDelta -= self.contentContainerNode.frame.height + 16.0
            }
            
            self.messageClipNode.layer.animateBounds(from: self.messageClipNode.bounds, to: toFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                completedBubble = true
                intermediateCompletion()
            })
            self.messageClipNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: (self.messageClipNode.bounds.width - initialWidth) / 2.0, y: clipDelta + self.scrollNode.view.contentOffset.y), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            
            self.messageBackgroundNode.layer.animateBounds(from: self.messageBackgroundNode.bounds, to: toFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            self.messageBackgroundNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: (initialWidth - self.messageClipNode.bounds.width) / 2.0, y: delta), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            
            var textXOffset: CGFloat = 0.0
            let textYOffset = self.textInputNode.textView.contentSize.height - self.textInputNode.textView.contentOffset.y - self.textInputNode.textView.frame.height
            if self.textInputNode.textView.numberOfLines == 1 && self.textInputNode.isRTL {
                textXOffset = initialWidth - self.messageClipNode.bounds.width
            }
            self.fromMessageTextNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: textXOffset, y: delta * 2.0 + textYOffset), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            self.toMessageTextNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: textXOffset, y: delta * 2.0 + textYOffset), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
        } else {
            completedBubble = true
        }
        
        let contentOffset = CGPoint(x:  self.sendButtonFrame.midX - self.contentContainerNode.frame.midX, y:  self.sendButtonFrame.midY - self.contentContainerNode.frame.midY)
        
        self.contentContainerNode.layer.animatePosition(from: CGPoint(), to: contentOffset, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
        self.contentContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
                
        transition.updateFrame(view: self.effectView, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let sideInset: CGFloat = self.sendButtonFrame.width - 1.0
        
        var contentSize = CGSize()
        contentSize.width = min(layout.size.width - 40.0, 250.0)
        var applyNodes: [(ASDisplayNode, CGFloat, (CGFloat) -> Void)] = []
        for itemNode in self.contentNodes {
            let (width, height, apply) = itemNode.updateLayout(maxWidth: layout.size.width - sideInset * 2.0)
            applyNodes.append((itemNode, height, apply))
            contentSize.width = max(contentSize.width, width)
            contentSize.height += height
        }
        
        let menuHeightWithInset = contentSize.height + 16.0
        
        let insets = layout.insets(options: [.statusBar, .input])
        let inputHeight = layout.inputHeight ?? 0.0
        
        let contentOffset = self.scrollNode.view.contentOffset.y
        
        var contentOrigin = CGPoint(x: layout.size.width - sideInset - contentSize.width - layout.safeInsets.right, y: layout.size.height - 6.0 - insets.bottom - contentSize.height)
        if inputHeight > 0.0 && !layout.isNonExclusive && self.animateInputField {
            contentOrigin.y += menuHeightWithInset
        }
        contentOrigin.y = min(contentOrigin.y + contentOffset, layout.size.height - 6.0 - layout.intrinsicInsets.bottom - contentSize.height)
        
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: contentOrigin, size: contentSize))
        var nextY: CGFloat = 0.0
        for (itemNode, height, apply) in applyNodes {
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: nextY), size: CGSize(width: contentSize.width, height: height)))
            apply(contentSize.width)
            nextY += height
        }
        
        let initialSendButtonFrame = self.sendButtonFrame
        var sendButtonFrame = CGRect(origin: CGPoint(x: layout.size.width - initialSendButtonFrame.width + 1.0 - UIScreenPixel - layout.safeInsets.right, y: layout.size.height - insets.bottom - initialSendButtonFrame.height), size: initialSendButtonFrame.size)
        if (inputHeight.isZero || layout.isNonExclusive) && self.animateInputField {
            sendButtonFrame.origin.y -= menuHeightWithInset
        }
        sendButtonFrame.origin.y = min(sendButtonFrame.origin.y + contentOffset, layout.size.height - layout.intrinsicInsets.bottom - initialSendButtonFrame.height)
        transition.updateFrame(node: self.sendButtonNode, frame: sendButtonFrame)
        
        var messageFrame = self.textFieldFrame
        messageFrame.size.width += 32.0
        messageFrame.origin.x -= 13.0
        messageFrame.origin.y = layout.size.height - messageFrame.origin.y - messageFrame.size.height - 1.0
        if inputHeight.isZero || layout.isNonExclusive {
            messageFrame.origin.y += menuHeightWithInset
        }
        
        if self.textInputNode.textView.attributedText.string.isEmpty {
            messageFrame.size.width = ceil(layout.size.width - messageFrame.origin.x - sendButtonFrame.width - layout.safeInsets.left - layout.safeInsets.right + 8.0)
        }
        
        var messageOriginDelta: CGFloat = 0.0
        if self.textInputNode.textView.numberOfLines == 1 || self.textInputNode.textView.attributedText.string.isEmpty {
            let textWidth = min(self.toMessageTextNode.textView.sizeThatFits(layout.size).width + 36.0, messageFrame.width)
            messageOriginDelta = messageFrame.width - textWidth
            messageFrame.origin.x += messageOriginDelta
            messageFrame.size.width = textWidth
        }
        
        let messageHeight = max(messageFrame.size.height, self.textInputNode.textView.contentSize.height + 2.0)
        messageFrame.size.height = messageHeight
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var scrollContentSize = CGSize(width: layout.size.width, height: messageHeight + max(0.0, messageFrame.origin.y))
        if messageHeight > layout.size.height - messageFrame.origin.y {
            scrollContentSize.height += insets.top + 16.0
        }
        self.scrollNode.view.contentSize = scrollContentSize
        
        let clipFrame = messageFrame
        transition.updateFrame(node: self.messageClipNode, frame: clipFrame)
        
        let backgroundFrame = CGRect(origin: CGPoint(), size: messageFrame.size)
        transition.updateFrame(node: self.messageBackgroundNode, frame: backgroundFrame)
        
        var textFrame = self.textFieldFrame
        textFrame.origin = CGPoint(x: 13.0, y: 6.0 - UIScreenPixel)
        textFrame.size.height = self.textInputNode.textView.contentSize.height
        
        if self.textInputNode.isRTL {
            textFrame.origin.x -= messageOriginDelta
        }
        
        self.fromMessageTextNode.frame = textFrame
        self.toMessageTextNode.frame = textFrame
    }
    
    @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    @objc private func sendButtonPressed() {
        self.sendButtonNode.isUserInteractionEnabled = false
        self.send?()
    }
}
