import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData

private let leftInset: CGFloat = 16.0
private let rightInset: CGFloat = 46.0

private final class ActionSheetItemNode: ASDisplayNode {
    private let title: String
    private let action: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    
    private var maxWidth: CGFloat?
    
    init(theme: PresentationTheme, title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.actionSheet.opaqueItemSeparatorColor
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = theme.actionSheet.opaqueItemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor)
        
        self.iconNode = ASImageNode()
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
        self.iconNode.contentMode = .center
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.separatorNode.backgroundColor = theme.actionSheet.opaqueItemSeparatorColor
        self.highlightedBackgroundNode.backgroundColor = theme.actionSheet.opaqueItemHighlightedBackgroundColor
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor)
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
        
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
        self.action()
    }
}

final class ChatSendMessageActionSheetControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private var presentationData: PresentationData
    private let sendButtonFrame: CGRect
    private let textFieldFrame: CGRect
    private let textInputNode: EditableTextNode
    private let accessoryPanelNode: AccessoryPanelNode?
    private let forwardedCount: Int?
    
    private let send: (() -> Void)?
    private let cancel: (() -> Void)?
    
    private let textCoverNode: ASDisplayNode
    private let buttonCoverNode: ASDisplayNode
    
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
    
    init(context: AccountContext, sendButtonFrame: CGRect, textInputNode: EditableTextNode, forwardedCount: Int?, send: (() -> Void)?, sendSilently: (() -> Void)?, cancel: (() -> Void)?) {
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.sendButtonFrame = sendButtonFrame
        self.textFieldFrame = textInputNode.convert(textInputNode.bounds, to: nil)
        self.textInputNode = textInputNode
        self.accessoryPanelNode = nil
        self.forwardedCount = forwardedCount
        
        self.send = send
        self.cancel = cancel
        
        self.textCoverNode = ASDisplayNode()
        self.buttonCoverNode = ASDisplayNode()
        
        self.effectView = UIVisualEffectView()
        if #available(iOS 9.0, *) {
        } else {
            if self.presentationData.theme.chatList.searchBarKeyboardColor == .dark {
                self.effectView.effect = UIBlurEffect(style: .dark)
            } else {
                self.effectView.effect = UIBlurEffect(style: .light)
            }
            self.effectView.alpha = 0.0
        }
        
        self.dimNode = ASDisplayNode()
        self.dimNode.alpha = 1.0
        if self.presentationData.theme.chatList.searchBarKeyboardColor == .light {
            self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.04)
        } else {
            self.dimNode.backgroundColor = presentationData.theme.chatList.backgroundColor.withAlphaComponent(0.2)
        }
        
        self.sendButtonNode = HighlightableButtonNode()
        self.sendButtonNode.imageNode.displayWithoutProcessing = false
        self.sendButtonNode.imageNode.displaysAsynchronously = false
        
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
        self.contentContainerNode.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
        self.contentContainerNode.cornerRadius = 12.0
        self.contentContainerNode.clipsToBounds = true
        
        var contentNodes: [ActionSheetItemNode] = []
        contentNodes.append(ActionSheetItemNode(theme: self.presentationData.theme, title: self.presentationData.strings.Conversation_SendMessage_SendSilently, action: {
            sendSilently?()
        }))
        self.contentNodes = contentNodes
        
        super.init()
        
        self.textCoverNode.backgroundColor = self.presentationData.theme.chat.inputPanel.inputBackgroundColor
        self.addSubnode(self.textCoverNode)
        
        self.buttonCoverNode.backgroundColor = self.presentationData.theme.chat.inputPanel.panelBackgroundColor
        self.addSubnode(self.buttonCoverNode)
        
        self.sendButtonNode.setImage(PresentationResourcesChat.chatInputPanelSendButtonImage(self.presentationData.theme), for: [])
        self.sendButtonNode.addTarget(self, action: #selector(sendButtonPressed), forControlEvents: .touchUpInside)
        
        if let attributedText = textInputNode.attributedText, !attributedText.string.isEmpty {
            self.fromMessageTextNode.attributedText = attributedText
            
            if let toAttributedText = self.fromMessageTextNode.attributedText?.mutableCopy() as? NSMutableAttributedString {
                toAttributedText.addAttribute(NSAttributedStringKey.foregroundColor, value: self.presentationData.theme.chat.message.outgoing.primaryTextColor, range: NSMakeRange(0, (toAttributedText.string as NSString).length))
                self.toMessageTextNode.attributedText = toAttributedText
            }
        } else {
            self.fromMessageTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.Conversation_InputTextPlaceholder, attributes: [NSAttributedStringKey.foregroundColor: self.presentationData.theme.chat.inputPanel.inputPlaceholderColor, NSAttributedStringKey.font: Font.regular(self.presentationData.fontSize.baseDisplaySize)])
        
            self.toMessageTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.ForwardedMessages(Int32(forwardedCount ?? 0)), attributes: [NSAttributedStringKey.foregroundColor: self.presentationData.theme.chat.message.outgoing.primaryTextColor, NSAttributedStringKey.font: Font.regular(self.presentationData.fontSize.baseDisplaySize)])
        }
        self.messageBackgroundNode.contentMode = .scaleToFill
        
        let graphics = PresentationResourcesChat.principalGraphics(self.presentationData.theme, wallpaper: self.presentationData.chatWallpaper)
        self.messageBackgroundNode.image = graphics.chatMessageBackgroundOutgoingImage
        
        self.view.addSubview(self.effectView)
        self.addSubnode(self.dimNode)
        
        self.addSubnode(self.contentContainerNode)
        self.addSubnode(self.scrollNode)
        
        self.addSubnode(self.sendButtonNode)
        self.scrollNode.addSubnode(self.messageClipNode)
        self.messageClipNode.addSubnode(self.messageBackgroundNode)
        self.messageClipNode.addSubnode(self.fromMessageTextNode)
        self.messageClipNode.addSubnode(self.toMessageTextNode)

        if let accessoryPanelNode = self.accessoryPanelNode {
             self.addSubnode(accessoryPanelNode)
        }
        
        self.contentNodes.forEach(self.contentContainerNode.addSubnode)
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
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        if self.presentationData.theme.chatList.searchBarKeyboardColor == .dark {
            self.effectView.effect = UIBlurEffect(style: .dark)
        } else {
            self.effectView.effect = UIBlurEffect(style: .light)
        }
        
        if self.presentationData.theme.chatList.searchBarKeyboardColor == .light {
            self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.04)
        } else {
            self.dimNode.backgroundColor = presentationData.theme.chatList.backgroundColor.withAlphaComponent(0.2)
        }
        
        self.contentContainerNode.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
        self.textCoverNode.backgroundColor = self.presentationData.theme.chat.inputPanel.inputBackgroundColor
        self.buttonCoverNode.backgroundColor = self.presentationData.theme.chat.inputPanel.panelBackgroundColor
        self.sendButtonNode.setImage(PresentationResourcesChat.chatInputPanelSendButtonImage(self.presentationData.theme), for: [])
        
        if let toAttributedText = self.textInputNode.attributedText?.mutableCopy() as? NSMutableAttributedString {
            toAttributedText.addAttribute(NSAttributedStringKey.foregroundColor, value: self.presentationData.theme.chat.message.outgoing.primaryTextColor, range: NSMakeRange(0, (toAttributedText.string as NSString).length))
            self.toMessageTextNode.attributedText = toAttributedText
        }
        
        let graphics = PresentationResourcesChat.principalGraphics(self.presentationData.theme, wallpaper: self.presentationData.chatWallpaper)
        self.messageBackgroundNode.image = graphics.chatMessageBackgroundOutgoingImage
        
        for node in self.contentNodes {
            node.updateTheme(presentationData.theme)
        }
    }
    
    func animateIn() {
        self.textInputNode.textView.setContentOffset(self.textInputNode.textView.contentOffset, animated: false)
        
        UIView.animate(withDuration: 0.4, animations: {
            if #available(iOS 9.0, *) {
                if self.presentationData.theme.chatList.searchBarKeyboardColor == .dark {
                    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                        self.effectView.effect = UIBlurEffect(style: .regular)
                        if self.effectView.subviews.count == 2 {
                            self.effectView.subviews[1].isHidden = true
                        }
                    } else {
                        self.effectView.effect = UIBlurEffect(style: .dark)
                    }
                } else {
                    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                        self.effectView.effect = UIBlurEffect(style: .regular)
                    } else {
                        self.effectView.effect = UIBlurEffect(style: .light)
                    }
                }
            } else {
                self.effectView.alpha = 1.0
            }
        }, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.presentationData.theme.chatList.searchBarKeyboardColor == .dark {
                if strongSelf.effectView.subviews.count == 2 {
                    strongSelf.effectView.subviews[1].isHidden = true
                }
            }
        })
        self.effectView.subviews[1].layer.removeAnimation(forKey: "backgroundColor")
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        self.contentContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.messageBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        self.fromMessageTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.toMessageTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, removeOnCompletion: false)
        
        if let layout = self.validLayout {
            let duration = 0.4
            
            self.sendButtonNode.layer.animateScale(from: 0.75, to: 1.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionLinear)
            self.sendButtonNode.layer.animatePosition(from: self.sendButtonFrame.center, to: self.sendButtonNode.position, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
            
            var initialWidth = self.textFieldFrame.width + 32.0
            if self.textInputNode.textView.attributedText.string.isEmpty {
                initialWidth = ceil(layout.size.width - self.textFieldFrame.origin.x - self.sendButtonFrame.width - layout.safeInsets.left - layout.safeInsets.right + 21.0)
            }
            
            let fromFrame = CGRect(origin: CGPoint(), size: CGSize(width: initialWidth, height: self.textFieldFrame.height + 2.0))
            let delta = (fromFrame.height - self.messageClipNode.bounds.height) / 2.0
            
            let inputHeight = layout.inputHeight ?? 0.0
            var clipDelta = delta
            if inputHeight.isZero {
                clipDelta -= 60.0
            }
            
            self.messageClipNode.layer.animateBounds(from: fromFrame, to: self.messageClipNode.bounds, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
            self.messageClipNode.layer.animatePosition(from: CGPoint(x: (self.messageClipNode.bounds.width - initialWidth) / 2.0, y: clipDelta), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true, completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.insertSubnode(strongSelf.contentContainerNode, aboveSubnode: strongSelf.scrollNode)
                }
            })
            
            self.messageBackgroundNode.layer.animateBounds(from: fromFrame, to: self.messageBackgroundNode.bounds, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
            self.messageBackgroundNode.layer.animatePosition(from: CGPoint(x: (initialWidth - self.messageClipNode.bounds.width) / 2.0, y: delta), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
           
            let textOffset = self.textInputNode.textView.contentSize.height - self.textInputNode.textView.contentOffset.y - self.textInputNode.textView.frame.height
            self.fromMessageTextNode.layer.animatePosition(from: CGPoint(x: 0.0, y: delta * 2.0 + textOffset), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.toMessageTextNode.layer.animatePosition(from: CGPoint(x: 0.0, y: delta * 2.0 + textOffset), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            
            self.contentContainerNode.layer.animatePosition(from: CGPoint(x: 160.0, y: 0.0), to: CGPoint(), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.contentContainerNode.layer.animateScale(from: 0.45, to: 1.0, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    func animateOut(cancel: Bool, completion: @escaping () -> Void) {
        self.isUserInteractionEnabled = false
        
        self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
        
        var completedEffect = false
        var completedButton = false
        var completedBubble = false
        var completedAlpha = false
        
        let intermediateCompletion: () -> Void = { [weak self] in
            if completedEffect && completedButton && completedBubble && completedAlpha {
                self?.textCoverNode.isHidden = true
                self?.buttonCoverNode.isHidden = true
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
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in })
        
        if cancel {
            self.fromMessageTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, delay: 0.15, removeOnCompletion: false)
            self.toMessageTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, delay: 0.15, removeOnCompletion: false)
            self.messageBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, delay: 0.15, removeOnCompletion: false, completion: { _ in
                completedAlpha = true
                intermediateCompletion()
            })
        } else {
            self.textCoverNode.isHidden = true
            self.messageClipNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                completedAlpha = true
                intermediateCompletion()
            })
        }
        
        if let layout = self.validLayout {
            let duration = 0.4
            
            self.sendButtonNode.layer.animatePosition(from: self.sendButtonNode.position, to: self.sendButtonFrame.center, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                completedButton = true
                intermediateCompletion()
            })
            
            if !cancel {
                self.buttonCoverNode.isHidden = true
                self.sendButtonNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2, timingFunction: kCAMediaTimingFunctionLinear, removeOnCompletion: false)
                self.sendButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionLinear, removeOnCompletion: false)
            }
            
            var initialWidth = self.textFieldFrame.width + 32.0
            if self.textInputNode.textView.attributedText.string.isEmpty {
                initialWidth = ceil(layout.size.width - self.textFieldFrame.origin.x - self.sendButtonFrame.width - layout.safeInsets.left - layout.safeInsets.right + 21.0)
            }
            
            let toFrame = CGRect(origin: CGPoint(), size: CGSize(width: initialWidth, height: self.textFieldFrame.height + 1.0))
            let delta = (toFrame.height - self.messageClipNode.bounds.height) / 2.0
            
            let inputHeight = layout.inputHeight ?? 0.0
            var clipDelta = delta
            if inputHeight.isZero {
                clipDelta -= 60.0
            }
            
            if cancel {
                self.messageClipNode.layer.animateBounds(from: self.messageClipNode.bounds, to: toFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                    completedBubble = true
                    intermediateCompletion()
                })
                self.messageClipNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: (self.messageClipNode.bounds.width - initialWidth) / 2.0, y: clipDelta + self.scrollNode.view.contentOffset.y), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                
                self.messageBackgroundNode.layer.animateBounds(from: self.messageBackgroundNode.bounds, to: toFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.messageBackgroundNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: (initialWidth - self.messageClipNode.bounds.width) / 2.0, y: delta), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                
                let textOffset = self.textInputNode.textView.contentSize.height - self.textInputNode.textView.contentOffset.y - self.textInputNode.textView.frame.height
                self.fromMessageTextNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: delta * 2.0 + textOffset), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                self.toMessageTextNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: delta * 2.0 + textOffset), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            } else {
                completedBubble = true
            }
            
            self.contentContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 160.0, y: 0.0), duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            self.contentContainerNode.layer.animateScale(from: 1.0, to: 0.4, duration: duration, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        transition.updateFrame(node: self.textCoverNode, frame: self.textFieldFrame)
        transition.updateFrame(node: self.buttonCoverNode, frame: self.sendButtonFrame.offsetBy(dx: 1.0, dy: 0.0))
        
        transition.updateFrame(view: self.effectView, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let sideInset: CGFloat = 43.0
        
        var contentSize = CGSize()
        contentSize.width = min(layout.size.width - 40.0, 240.0)
        var applyNodes: [(ASDisplayNode, CGFloat, (CGFloat) -> Void)] = []
        for itemNode in self.contentNodes {
            let (width, height, apply) = itemNode.updateLayout(maxWidth: layout.size.width - sideInset * 2.0)
            applyNodes.append((itemNode, height, apply))
            contentSize.width = max(contentSize.width, width)
            contentSize.height += height
        }
        
        let insets = layout.insets(options: [.statusBar, .input])
        let inputHeight = layout.inputHeight ?? 0.0
        
        let contentOffset = self.scrollNode.view.contentOffset.y
        
        var contentOrigin = CGPoint(x: layout.size.width - sideInset - contentSize.width - layout.safeInsets.right, y: layout.size.height - 6.0 - insets.bottom - contentSize.height)
        if inputHeight > 0.0 {
            contentOrigin.y += 60.0
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
        if inputHeight.isZero {
            sendButtonFrame.origin.y -= 60.0
        }
        sendButtonFrame.origin.y = min(sendButtonFrame.origin.y + contentOffset, layout.size.height - layout.intrinsicInsets.bottom - initialSendButtonFrame.height)
        transition.updateFrame(node: self.sendButtonNode, frame: sendButtonFrame)
        
        var messageFrame = self.textFieldFrame
        messageFrame.size.width += 32.0
        messageFrame.origin.x -= 13.0
        messageFrame.origin.y = layout.size.height - messageFrame.origin.y - messageFrame.size.height - 1.0
        if inputHeight.isZero {
            messageFrame.origin.y += 60.0
        }
        
        if self.textInputNode.textView.attributedText.string.isEmpty {
            messageFrame.size.width = ceil(layout.size.width - messageFrame.origin.x - sendButtonFrame.width - layout.safeInsets.left - layout.safeInsets.right + 8.0)
        }
        
        if self.textInputNode.textView.numberOfLines == 1 || self.textInputNode.textView.attributedText.string.isEmpty {
            let textWidth = min(self.toMessageTextNode.textView.sizeThatFits(layout.size).width + 36.0, messageFrame.width)
            messageFrame.origin.x += messageFrame.width - textWidth
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
        self.fromMessageTextNode.frame = textFrame
        self.toMessageTextNode.frame = textFrame
        
        if let accessoryPanelNode = self.accessoryPanelNode {
            let size = accessoryPanelNode.calculateSizeThatFits(CGSize(width: messageFrame.width, height: 45.0))
            accessoryPanelNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.textFieldFrame.minY - size.height - 7.0), size: size)
        }
    }
    
    @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    @objc private func sendButtonPressed() {
        self.send?()
    }
}
