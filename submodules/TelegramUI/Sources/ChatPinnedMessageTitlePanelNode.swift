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
import InvisibleInkDustNode
import TextFormat
import ChatPresentationInterfaceState

private enum PinnedMessageAnimation {
    case slideToTop
    case slideToBottom
}

private final class ButtonsContainerNode: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let subnodes = self.subnodes {
            for subnode in subnodes {
                if let result = subnode.view.hitTest(self.view.convert(point, to: subnode.view), with: event) {
                    return result
                }
            }
        }
        return nil
    }
}

final class ChatPinnedMessageTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    private let tapButton: HighlightTrackingButtonNode
    private let buttonsContainer: ButtonsContainerNode
    private let closeButton: HighlightableButtonNode
    private let listButton: HighlightableButtonNode
    private let activityIndicatorContainer: ASDisplayNode
    private let activityIndicator: RadialStatusNode
    
    private let contextContainer: ContextControllerSourceNode
    private let clippingContainer: ASDisplayNode
    private let contentContainer: ASDisplayNode
    private let contentTextContainer: ASDisplayNode
    private let lineNode: AnimatedNavigationStripeNode
    private let titleNode: AnimatedCountLabelNode
    private let textNode: TextNode
    private var spoilerTextNode: TextNode?
    private var dustNode: InvisibleInkDustNode?
    private let actionButton: HighlightableButtonNode
    private let actionButtonTitleNode: ImmediateTextNode
    private let actionButtonBackgroundNode: ASImageNode
    
    private let imageNode: TransformImageNode
    private let imageNodeContainer: ASDisplayNode

    private let separatorNode: ASDisplayNode

    private var currentLayout: (CGFloat, CGFloat, CGFloat)?
    private var currentMessage: ChatPinnedMessage?
    private var previousMediaReference: AnyMediaReference?
    
    private var isReplyThread: Bool = false
    
    private let fetchDisposable = MetaDisposable()
    
    private var statusDisposable: Disposable?

    private let queue = Queue()
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let containerResult = self.contentTextContainer.hitTest(point.offsetBy(dx: -self.contentTextContainer.frame.minX, dy: -self.contentTextContainer.frame.minY), with: event)
        if containerResult?.asyncdisplaykit_node === self.dustNode, self.dustNode?.isRevealed == false {
            return containerResult
        }
        let result = super.hitTest(point, with: event)
        return result
    }
    
    init(context: AccountContext) {
        self.context = context
        
        self.tapButton = HighlightTrackingButtonNode()
        
        self.buttonsContainer = ButtonsContainerNode()
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.actionButton = HighlightableButtonNode()
        self.actionButton.isHidden = true
        self.actionButtonTitleNode = ImmediateTextNode()
        self.actionButtonTitleNode.isHidden = true
        self.actionButtonBackgroundNode = ASImageNode()
        self.actionButtonBackgroundNode.isHidden = true
        self.actionButtonBackgroundNode.displaysAsynchronously = false
        
        self.listButton = HighlightableButtonNode()
        self.listButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.listButton.displaysAsynchronously = false
        
        self.activityIndicatorContainer = ASDisplayNode()
        self.activityIndicatorContainer.isUserInteractionEnabled = false
        self.activityIndicator = RadialStatusNode(backgroundNodeColor: .clear)
        self.activityIndicator.isUserInteractionEnabled = false
        self.activityIndicatorContainer.addSubnode(self.activityIndicator)
        self.activityIndicator.alpha = 0.0
        ContainedViewLayoutTransition.immediate.updateSublayerTransformScale(node: self.activityIndicatorContainer, scale: 0.1)
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.contextContainer = ContextControllerSourceNode()
        
        self.clippingContainer = ASDisplayNode()
        self.clippingContainer.clipsToBounds = true
        
        self.contentContainer = ASDisplayNode()
        self.contentTextContainer = ASDisplayNode()
        
        self.lineNode = AnimatedNavigationStripeNode()
        
        self.titleNode = AnimatedCountLabelNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.reverseAnimationDirection = true
        
        self.textNode = TextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        
        self.imageNodeContainer = ASDisplayNode()
        
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
        
        self.actionButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.actionButton.layer.removeAnimation(forKey: "opacity")
                    strongSelf.actionButton.alpha = 0.4
                } else {
                    strongSelf.actionButton.alpha = 1.0
                    strongSelf.actionButton.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.listButton.addTarget(self, action: #selector(self.listPressed), forControlEvents: [.touchUpInside])
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: [.touchUpInside])
        
        self.addSubnode(self.contextContainer)
        
        self.contextContainer.addSubnode(self.clippingContainer)
        self.clippingContainer.addSubnode(self.contentContainer)
        self.contextContainer.addSubnode(self.lineNode)
        self.contentTextContainer.addSubnode(self.titleNode)
        self.contentTextContainer.addSubnode(self.textNode)
        self.contentContainer.addSubnode(self.contentTextContainer)
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.contentContainer.addSubnode(self.imageNodeContainer)
        
        self.actionButton.addSubnode(self.actionButtonBackgroundNode)
        self.actionButton.addSubnode(self.actionButtonTitleNode)
        self.buttonsContainer.addSubnode(self.actionButton)
        self.buttonsContainer.addSubnode(self.closeButton)
        self.buttonsContainer.addSubnode(self.listButton)
        self.contextContainer.addSubnode(self.buttonsContainer)
        self.contextContainer.addSubnode(self.activityIndicatorContainer)
        
        self.tapButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        self.contextContainer.addSubnode(self.tapButton)
        
        self.addSubnode(self.separatorNode)
        
        self.contextContainer.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            if let interfaceInteraction = strongSelf.interfaceInteraction, let _ = strongSelf.currentMessage, !strongSelf.isReplyThread {
                interfaceInteraction.activatePinnedListPreview(strongSelf.contextContainer, gesture)
            }
        }
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.statusDisposable?.dispose()
    }
    
    private var theme: PresentationTheme?
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        let panelHeight: CGFloat = 50.0
        var themeUpdated = false
        
        self.contextContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        
        if self.theme !== interfaceState.theme {
            themeUpdated = true
            self.theme = interfaceState.theme
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(interfaceState.theme), for: [])
            self.listButton.setImage(PresentationResourcesChat.chatInputPanelPinnedListIconImage(interfaceState.theme), for: [])
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
            
            self.actionButtonBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 14.0 * 2.0, color: interfaceState.theme.list.itemCheckColors.fillColor, strokeColor: nil, strokeWidth: nil, backgroundColor: nil)
        }
        
        if self.statusDisposable == nil, let interfaceInteraction = self.interfaceInteraction, let statuses = interfaceInteraction.statuses {
            self.statusDisposable = (statuses.loadingMessage
            |> map { status -> Bool in
                return status == .pinnedMessage
            }
            |> deliverOnMainQueue).start(next: { [weak self] isLoading in
                guard let strongSelf = self else {
                    return
                }
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                if isLoading {
                    if strongSelf.activityIndicator.alpha.isZero {
                        transition.updateAlpha(node: strongSelf.activityIndicator, alpha: 1.0)
                        transition.updateSublayerTransformScale(node: strongSelf.activityIndicatorContainer, scale: 1.0)
                        
                        transition.updateAlpha(node: strongSelf.buttonsContainer, alpha: 0.0)
                        transition.updateSublayerTransformScale(node: strongSelf.buttonsContainer, scale: 0.1)
                        
                        if let theme = strongSelf.theme {
                            strongSelf.activityIndicator.transitionToState(.progress(color: theme.chat.inputPanel.panelControlAccentColor, lineWidth: nil, value: nil, cancelEnabled: false, animateRotation: true), animated: false, completion: {
                            })
                        }
                    }
                } else {
                    if !strongSelf.activityIndicator.alpha.isZero {
                        transition.updateAlpha(node: strongSelf.activityIndicator, alpha: 0.0, completion: { [weak self] completed in
                            if completed {
                                self?.activityIndicator.transitionToState(.none, animated: false, completion: {
                                })
                            }
                        })
                        transition.updateSublayerTransformScale(node: strongSelf.activityIndicatorContainer, scale: 0.1)
                        
                        transition.updateAlpha(node: strongSelf.buttonsContainer, alpha: 1.0)
                        transition.updateSublayerTransformScale(node: strongSelf.buttonsContainer, scale: 1.0)
                    }
                }
            })
        }
        
        let isReplyThread: Bool
        if case .replyThread = interfaceState.chatLocation {
            isReplyThread = true
        } else {
            isReplyThread = false
        }
        self.isReplyThread = isReplyThread
        
        self.contextContainer.isGestureEnabled = !isReplyThread
        
        var actionTitle: String?
        var messageUpdated = false
        var messageUpdatedAnimation: PinnedMessageAnimation?
        if let currentMessage = self.currentMessage, let pinnedMessage = interfaceState.pinnedMessage {
            if currentMessage != pinnedMessage {
                messageUpdated = true
            }
            if currentMessage.message.id != pinnedMessage.message.id {
                if currentMessage.message.id < pinnedMessage.message.id {
                    messageUpdatedAnimation = .slideToTop
                } else {
                    messageUpdatedAnimation = .slideToBottom
                }
            }
        } else if (self.currentMessage != nil) != (interfaceState.pinnedMessage != nil) {
            messageUpdated = true
        }
        
        if let message = interfaceState.pinnedMessage {
            for attribute in message.message.attributes {
                if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), attribute.rows.count == 1, attribute.rows[0].buttons.count == 1 {
                    actionTitle = attribute.rows[0].buttons[0].title
                }
            }
        } else {
            actionTitle = nil
        }
        
        var displayCloseButton = false
        var displayListButton = false
        
        if isReplyThread || actionTitle != nil {
            displayCloseButton = false
            displayListButton = false
        } else if let message = interfaceState.pinnedMessage {
            if message.totalCount > 1 {
                displayCloseButton = false
                displayListButton = true
            } else {
                displayCloseButton = true
                displayListButton = false
            }
        } else {
            displayCloseButton = false
            displayListButton = true
        }
        
        if displayCloseButton != !self.closeButton.isHidden {
            if transition.isAnimated {
                if displayCloseButton {
                    self.closeButton.isHidden = false
                    self.closeButton.layer.removeAllAnimations()
                    
                    self.closeButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.closeButton.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                } else {
                    self.closeButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] completed in
                        guard let strongSelf = self, completed else {
                            return
                        }
                        strongSelf.closeButton.isHidden = true
                        strongSelf.closeButton.layer.removeAllAnimations()
                    })
                    self.closeButton.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                }
            } else {
                self.closeButton.isHidden = !displayCloseButton
                self.closeButton.layer.removeAllAnimations()
            }
        }
        if displayListButton != !self.listButton.isHidden {
            if transition.isAnimated {
                if displayListButton {
                    self.listButton.isHidden = false
                    self.listButton.layer.removeAllAnimations()
                    
                    self.listButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.listButton.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                } else {
                    self.listButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] completed in
                        guard let strongSelf = self, completed else {
                            return
                        }
                        strongSelf.listButton.isHidden = true
                        strongSelf.listButton.layer.removeAllAnimations()
                    })
                    self.listButton.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                }
            } else {
                self.listButton.isHidden = !displayListButton
                self.listButton.layer.removeAllAnimations()
            }
        }
        
        let rightInset: CGFloat = 18.0 + rightInset
        
        var tapButtonRightInset: CGFloat = rightInset
        
        let buttonsContainerSize = CGSize(width: 16.0, height: panelHeight)
        self.buttonsContainer.frame = CGRect(origin: CGPoint(x: width - buttonsContainerSize.width - rightInset, y: 0.0), size: buttonsContainerSize)
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        
        if let actionTitle = actionTitle {
            var actionButtonTransition = transition
            var animateButtonIn = false
            if self.actionButton.isHidden {
                actionButtonTransition = .immediate
                animateButtonIn = true
            } else if transition.isAnimated, messageUpdated, actionTitle != self.actionButtonTitleNode.attributedText?.string {
                if let buttonSnapshot = self.actionButton.view.snapshotView(afterScreenUpdates: false) {
                    animateButtonIn = true
                    buttonSnapshot.frame = self.actionButton.frame
                    self.actionButton.view.superview?.insertSubview(buttonSnapshot, belowSubview: self.actionButton.view)
                    
                    buttonSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak buttonSnapshot] _ in
                        buttonSnapshot?.removeFromSuperview()
                    })
                    buttonSnapshot.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                }
            }
            
            self.actionButton.isHidden = false
            self.actionButtonBackgroundNode.isHidden = false
            self.actionButtonTitleNode.isHidden = false
            
            self.actionButtonTitleNode.attributedText = NSAttributedString(string: actionTitle, font: Font.with(size: 15.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor:  interfaceState.theme.list.itemCheckColors.foregroundColor)
            
            let actionButtonTitleSize = self.actionButtonTitleNode.updateLayout(CGSize(width: 150.0, height: .greatestFiniteMagnitude))
            let actionButtonSize = CGSize(width: max(actionButtonTitleSize.width + 20.0, 40.0), height: 28.0)
            let actionButtonFrame = CGRect(origin: CGPoint(x: buttonsContainerSize.width + 11.0 - actionButtonSize.width, y: floor((panelHeight - actionButtonSize.height) / 2.0)), size: actionButtonSize)
            actionButtonTransition.updateFrame(node: self.actionButton, frame: actionButtonFrame)
            actionButtonTransition.updateFrame(node: self.actionButtonBackgroundNode, frame: CGRect(origin: CGPoint(), size: actionButtonFrame.size))
            actionButtonTransition.updateFrame(node: self.actionButtonTitleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((actionButtonFrame.width - actionButtonTitleSize.width) / 2.0), y: floorToScreenPixels((actionButtonFrame.height - actionButtonTitleSize.height) / 2.0)), size: actionButtonTitleSize))
            
            tapButtonRightInset = 18.0 + actionButtonFrame.width
            
            if animateButtonIn {
                self.actionButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.actionButton.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
            }
        } else if !self.actionButton.isHidden {
            self.actionButton.isHidden = true
            self.actionButtonBackgroundNode.isHidden = true
            self.actionButtonTitleNode.isHidden = true
            
            if transition.isAnimated {
                if let buttonSnapshot = self.actionButton.view.snapshotView(afterScreenUpdates: false) {
                    buttonSnapshot.frame = self.actionButton.frame
                    self.actionButton.view.superview?.insertSubview(buttonSnapshot, belowSubview: self.actionButton.view)
                    
                    buttonSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak buttonSnapshot] _ in
                        buttonSnapshot?.removeFromSuperview()
                    })
                    buttonSnapshot.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                }
            }
        }
        
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: buttonsContainerSize.width - closeButtonSize.width + 1.0, y: 19.0), size: closeButtonSize))
        
        let listButtonSize = self.listButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.listButton, frame: CGRect(origin: CGPoint(x: buttonsContainerSize.width - listButtonSize.width + 4.0, y: 13.0), size: listButtonSize))
        
        let indicatorSize = CGSize(width: 22.0, height: 22.0)
        transition.updateFrame(node: self.activityIndicatorContainer, frame: CGRect(origin: CGPoint(x: width - rightInset - indicatorSize.width + 5.0, y: 15.0), size: indicatorSize))
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(), size: indicatorSize))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        self.tapButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: width - tapButtonRightInset, height: panelHeight))
        
        self.clippingContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        self.contentContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        
        if self.currentLayout?.0 != width || self.currentLayout?.1 != leftInset || self.currentLayout?.2 != rightInset || messageUpdated || themeUpdated {
            self.currentLayout = (width, leftInset, rightInset)
            
            let previousMessageWasNil = self.currentMessage == nil
            self.currentMessage = interfaceState.pinnedMessage
            
            if let currentMessage = self.currentMessage, let currentLayout = self.currentLayout {
                self.dustNode?.update(revealed: false, animated: false)
                self.enqueueTransition(width: currentLayout.0, panelHeight: panelHeight, leftInset: currentLayout.1, rightInset: currentLayout.2, transition: .immediate, animation: messageUpdatedAnimation, pinnedMessage: currentMessage, theme: interfaceState.theme, strings: interfaceState.strings, nameDisplayOrder: interfaceState.nameDisplayOrder, dateTimeFormat: interfaceState.dateTimeFormat, accountPeerId: self.context.account.peerId, firstTime: previousMessageWasNil, isReplyThread: isReplyThread)
            }
        }
        
        self.currentLayout = (width, leftInset, rightInset)
        
        /*if self.currentLayout?.0 != width || self.currentLayout?.1 != leftInset || self.currentLayout?.2 != rightInset || messageUpdated {
            self.currentLayout = (width, leftInset, rightInset)
            
            if let currentMessage = self.currentMessage {
                self.enqueueTransition(width: width, panelHeight: panelHeight, leftInset: leftInset, rightInset: rightInset, transition: .immediate, animation: .none, pinnedMessage: currentMessage, theme: interfaceState.theme, strings: interfaceState.strings, nameDisplayOrder: interfaceState.nameDisplayOrder, dateTimeFormat: interfaceState.dateTimeFormat, accountPeerId: interfaceState.accountPeerId, firstTime: true, isReplyThread: isReplyThread)
            }
        }*/
        
        return LayoutResult(backgroundHeight: panelHeight, insetHeight: panelHeight)
    }
    
    private func enqueueTransition(width: CGFloat, panelHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, animation: PinnedMessageAnimation?, pinnedMessage: ChatPinnedMessage, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, accountPeerId: PeerId, firstTime: Bool, isReplyThread: Bool) {
        let message = pinnedMessage.message
        
        var animationTransition: ContainedViewLayoutTransition = .immediate
        
        if let animation = animation {
            animationTransition = .animated(duration: 0.2, curve: .easeInOut)
            
            if let copyView = self.textNode.view.snapshotView(afterScreenUpdates: false) {
                let offset: CGFloat
                switch animation {
                case .slideToTop:
                    offset = -10.0
                case .slideToBottom:
                    offset = 10.0
                }
                
                copyView.frame = self.textNode.frame
                self.textNode.view.superview?.addSubview(copyView)
                copyView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.2, removeOnCompletion: false, additive: true)
                copyView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak copyView] _ in
                    copyView?.removeFromSuperview()
                })
                self.textNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -offset), to: CGPoint(), duration: 0.2, additive: true)
                self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
        
        let makeTitleLayout = self.titleNode.asyncLayout()
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeSpoilerTextLayout = TextNode.asyncLayout(self.spoilerTextNode)
        let imageNodeLayout = self.imageNode.asyncLayout()
        
        let previousMediaReference = self.previousMediaReference
        let context = self.context
        
        let targetQueue: Queue
        if firstTime {
            targetQueue = Queue.mainQueue()
        } else {
            targetQueue = self.queue
        }
        
        let contentLeftInset: CGFloat = leftInset + 10.0
        var textLineInset: CGFloat = 10.0
        var rightInset: CGFloat = 14.0 + rightInset
        
        let textRightInset: CGFloat = 0.0
        
        if !self.actionButton.isHidden {
            rightInset += self.actionButton.bounds.width - 14.0
        }
        
        targetQueue.async { [weak self] in
            var updatedMediaReference: AnyMediaReference?
            var imageDimensions: CGSize?
            
            var titleStrings: [AnimatedCountLabelNode.Segment] = []
            if pinnedMessage.totalCount == 2 {
                if pinnedMessage.index == 0 {
                    titleStrings.append(.text(0, NSAttributedString(string: "\(strings.Conversation_PinnedPreviousMessage) ", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor)))
                } else {
                    titleStrings.append(.text(0, NSAttributedString(string: "\(strings.Conversation_PinnedMessage) ", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor)))
                }
            } else if pinnedMessage.totalCount > 1 && pinnedMessage.index != pinnedMessage.totalCount - 1 {
                titleStrings.append(.text(0, NSAttributedString(string: "\(strings.Conversation_PinnedMessage)", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor)))
                titleStrings.append(.text(1, NSAttributedString(string: " #", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor)))
                titleStrings.append(.number(pinnedMessage.index + 1, NSAttributedString(string: "\(pinnedMessage.index + 1)", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor)))
            } else {
                titleStrings.append(.text(0, NSAttributedString(string: "\(strings.Conversation_PinnedMessage) ", font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor)))
            }
            
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
                        if !file.isInstantVideo, let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                            imageDimensions = representation.dimensions.cgSize
                        }
                        break
                    }
                }
            }
            
            if isReplyThread {
                let titleString: String
                if let author = message.effectiveAuthor {
                    titleString = EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                } else {
                    titleString = ""
                }
                titleStrings = [.text(0, NSAttributedString(string: titleString, font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor))]
            } else {
                for media in message.media {
                    if let media = media as? TelegramMediaInvoice {
                        titleStrings = [.text(0, NSAttributedString(string: media.title, font: Font.medium(15.0), textColor: theme.chat.inputPanel.panelControlAccentColor))]
                        break
                    }
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
                            updateImageSignal = chatWebpageSnippetFile(account: context.account, mediaReference: fileReference.abstract, representation: iconImageRepresentation)
                        }
                    }
                } else {
                    updateImageSignal = .single({ _ in return nil })
                }
            }
            let (titleLayout, titleApply) = makeTitleLayout(CGSize(width: width - textLineInset - contentLeftInset - rightInset - textRightInset, height: CGFloat.greatestFiniteMagnitude), titleStrings)
            
            let (textString, _, isText) = descriptionStringForMessage(contentSettings: context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, accountPeerId: accountPeerId)
            
            let messageText: NSAttributedString
            let textFont = Font.regular(15.0)
            if isText {
                let entities = (message.textEntitiesAttribute?.entities ?? []).filter { entity in
                    if case .Spoiler = entity.type {
                        return true
                    } else {
                        return false
                    }
                }
                let textColor = theme.chat.inputPanel.primaryTextColor
                if entities.count > 0 {
                    messageText = stringWithAppliedEntities(trimToLineCount(message.text, lineCount: 1), entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false)
                } else {
                    messageText = NSAttributedString(string: foldLineBreaks(textString), font: textFont, textColor: textColor)
                }
            } else {
                messageText = NSAttributedString(string: foldLineBreaks(textString), font: textFont, textColor: message.media.isEmpty || message.media.first is TelegramMediaWebpage ? theme.chat.inputPanel.primaryTextColor : theme.chat.inputPanel.secondaryTextColor)
            }
            
            let textConstrainedSize = CGSize(width: width - textLineInset - contentLeftInset - rightInset - textRightInset, height: CGFloat.greatestFiniteMagnitude)
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: messageText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0)))
            
            let spoilerTextLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if !textLayout.spoilers.isEmpty {
                spoilerTextLayoutAndApply = makeSpoilerTextLayout(TextNodeLayoutArguments(attributedString: messageText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0), displaySpoilers: true))
            } else {
                spoilerTextLayoutAndApply = nil
            }
            
            Queue.mainQueue().async {
                if let strongSelf = self {
                    let _ = titleApply(animation != nil)
                    let _ = textApply()
                    
                    strongSelf.previousMediaReference = updatedMediaReference
                    
                    animationTransition.updateFrameAdditive(node: strongSelf.contentTextContainer, frame: CGRect(origin: CGPoint(x: contentLeftInset + textLineInset, y: 0.0), size: CGSize(width: width, height: panelHeight)))
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 5.0), size: titleLayout.size)
                    
                    let textFrame = CGRect(origin: CGPoint(x: 0.0, y: 23.0), size: textLayout.size)
                    strongSelf.textNode.frame = textFrame
                    
                    
                    if let (_, spoilerTextApply) = spoilerTextLayoutAndApply {
                        let spoilerTextNode = spoilerTextApply()
                        if strongSelf.spoilerTextNode == nil {
                            spoilerTextNode.alpha = 0.0
                            spoilerTextNode.isUserInteractionEnabled = false
                            spoilerTextNode.contentMode = .topLeft
                            spoilerTextNode.contentsScale = UIScreenScale
                            spoilerTextNode.displaysAsynchronously = false
                            strongSelf.contentTextContainer.insertSubnode(spoilerTextNode, aboveSubnode: strongSelf.textNode)
                            
                            strongSelf.spoilerTextNode = spoilerTextNode
                        }
                        
                        strongSelf.spoilerTextNode?.frame = textFrame
                        
                        let dustNode: InvisibleInkDustNode
                        if let current = strongSelf.dustNode {
                            dustNode = current
                        } else {
                            dustNode = InvisibleInkDustNode(textNode: spoilerTextNode)
                            strongSelf.dustNode = dustNode
                            strongSelf.contentTextContainer.insertSubnode(dustNode, aboveSubnode: spoilerTextNode)
                        }
                        dustNode.frame = textFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0)
                        dustNode.update(size: dustNode.frame.size, color: theme.chat.inputPanel.secondaryTextColor, textColor: theme.chat.inputPanel.primaryTextColor, rects: textLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: textLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                    } else if let spoilerTextNode = strongSelf.spoilerTextNode {
                        strongSelf.spoilerTextNode = nil
                        spoilerTextNode.removeFromSupernode()
                        
                        if let dustNode = strongSelf.dustNode {
                            strongSelf.dustNode = nil
                            dustNode.removeFromSupernode()
                        }
                    }
                    
                    let lineFrame = CGRect(origin: CGPoint(x: contentLeftInset, y: 0.0), size: CGSize(width: 2.0, height: panelHeight))
                    animationTransition.updateFrame(node: strongSelf.lineNode, frame: lineFrame)
                    strongSelf.lineNode.update(
                        colors: AnimatedNavigationStripeNode.Colors(
                            foreground: theme.chat.inputPanel.panelControlAccentColor,
                            background: theme.chat.inputPanel.panelControlAccentColor.withAlphaComponent(0.5),
                            clearBackground: theme.chat.inputPanel.panelBackgroundColor
                        ),
                        configuration: AnimatedNavigationStripeNode.Configuration(
                            height: panelHeight,
                            index: pinnedMessage.index,
                            count: pinnedMessage.totalCount
                        ),
                        transition: animationTransition
                    )
                    
                    strongSelf.imageNodeContainer.frame = CGRect(origin: CGPoint(x: contentLeftInset + 9.0, y: 7.0), size: CGSize(width: 35.0, height: 35.0))
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 35.0, height: 35.0))
                    
                    if let applyImage = applyImage {
                        applyImage()
                        
                        animationTransition.updateSublayerTransformScale(node: strongSelf.imageNodeContainer, scale: 1.0)
                        animationTransition.updateAlpha(node: strongSelf.imageNodeContainer, alpha: 1.0, beginWithCurrentState: true)
                    } else {
                        animationTransition.updateSublayerTransformScale(node: strongSelf.imageNodeContainer, scale: 0.1)
                        animationTransition.updateAlpha(node: strongSelf.imageNodeContainer, alpha: 0.0, beginWithCurrentState: true)
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
            if self.isReplyThread {
                interfaceInteraction.scrollToTop()
            } else {
                interfaceInteraction.navigateToMessage(message.message.id, false, true, .pinnedMessage)
            }
        }
    }
    
    @objc func closePressed() {
        if let interfaceInteraction = self.interfaceInteraction, let message = self.currentMessage {
            interfaceInteraction.unpinMessage(message.message.id, true, nil)
        }
    }
    
    @objc func listPressed() {
        if let interfaceInteraction = self.interfaceInteraction, let message = self.currentMessage {
            interfaceInteraction.openPinnedList(message.message.id)
        }
    }
    
    @objc private func actionButtonPressed() {
        if let interfaceInteraction = self.interfaceInteraction, let controller = interfaceInteraction.chatController() as? ChatControllerImpl, let controllerInteraction = controller.controllerInteraction, let message = self.currentMessage?.message {
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), attribute.rows.count == 1, attribute.rows[0].buttons.count == 1 {
                    let button = attribute.rows[0].buttons[0]
                    switch button.action {
                    case .text:
                        controllerInteraction.sendMessage(button.title)
                    case let .url(url):
                        controllerInteraction.openUrl(url, true, nil, nil)
                    case .requestMap:
                        controllerInteraction.shareCurrentLocation()
                    case .requestPhone:
                        controllerInteraction.shareAccountContact()
                    case .openWebApp:
                        controllerInteraction.requestMessageActionCallback(message.id, nil, true, false)
                    case let .callback(requiresPassword, data):
                        controllerInteraction.requestMessageActionCallback(message.id, data, false, requiresPassword)
                    case let .switchInline(samePeer, query):
                        var botPeer: Peer?
                        
                        var found = false
                        for attribute in message.attributes {
                            if let attribute = attribute as? InlineBotMessageAttribute {
                                if let peerId = attribute.peerId {
                                    botPeer = message.peers[peerId]
                                    found = true
                                }
                            }
                        }
                        if !found {
                            botPeer = message.author
                        }
                        
                        var peerId: PeerId?
                        if samePeer {
                            peerId = message.id.peerId
                        }
                        if let botPeer = botPeer, let addressName = botPeer.addressName {
                            controllerInteraction.activateSwitchInline(peerId, "@\(addressName) \(query)")
                        }
                    case .payment:
                        controllerInteraction.openCheckoutOrReceipt(message.id)
                    case let .urlAuth(url, buttonId):
                        controllerInteraction.requestMessageActionUrlAuth(url, .message(id: message.id, buttonId: buttonId))
                    case .setupPoll:
                        break
                    case let .openUserProfile(peerId):
                        controllerInteraction.openPeer(peerId, .info, nil, nil)
                    case let .openWebView(url, simple):
                        controllerInteraction.openWebView(button.title, url, simple, false)
                    }
                    
                    break
                }
            }
        }
    }
}
