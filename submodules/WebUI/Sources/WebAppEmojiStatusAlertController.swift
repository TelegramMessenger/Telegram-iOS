import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import AvatarNode
import EmojiTextAttachmentView
import TextFormat
import Markdown

private final class IconsNode: ASDisplayNode {
    private let context: AccountContext
    private var animationLayer: InlineStickerItemLayer?
    
    private var files: [TelegramMediaFile.Accessor]
    private var currentIndex = 0
    private var switchingToNext = false
    
    private var timer: SwiftSignalKit.Timer?
    
    private var currentParams: (size: CGSize, theme: PresentationTheme)?
    
    init(context: AccountContext, files: [TelegramMediaFile.Accessor]) {
        self.context = context
        self.files = files
        
        super.init()
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func updateLayout(size: CGSize, theme: PresentationTheme) {
        self.currentParams = (size, theme)

        if self.timer == nil {
            self.timer = SwiftSignalKit.Timer(timeout: 2.5, repeat: true, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.switchingToNext = true
                if let (size, theme) = self.currentParams {
                    self.updateLayout(size: size, theme: theme)
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
        
        let animationLayer: InlineStickerItemLayer
        var disappearingAnimationLayer: InlineStickerItemLayer?
        if let current = self.animationLayer, !self.switchingToNext {
            animationLayer = current
        } else {
            if self.switchingToNext {
                self.currentIndex = (self.currentIndex + 1) % self.files.count
                disappearingAnimationLayer = self.animationLayer
                self.switchingToNext = false
            }
            let file = self.files[self.currentIndex]._parse()
            let emoji = ChatTextInputTextCustomEmojiAttribute(
                interactivelySelectedFromPackId: nil,
                fileId: file.fileId.id,
                file: file
            )
            animationLayer = InlineStickerItemLayer(
                context: .account(self.context),
                userLocation: .other,
                attemptSynchronousLoad: false,
                emoji: emoji,
                file: file,
                cache: self.context.animationCache,
                renderer: self.context.animationRenderer,
                unique: true,
                placeholderColor: theme.list.mediaPlaceholderColor,
                pointSize: CGSize(width: 20.0, height: 20.0),
                loopCount: 1
            )
            animationLayer.isVisibleForAnimations = true
            animationLayer.dynamicColor = theme.actionSheet.controlAccentColor
            self.view.layer.addSublayer(animationLayer)
            self.animationLayer = animationLayer
            
            animationLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            animationLayer.animatePosition(from: CGPoint(x: 0.0, y: 10.0), to: .zero, duration: 0.2, additive: true)
            animationLayer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
        }
        
        animationLayer.frame = CGRect(origin: .zero, size: CGSize(width: 20.0, height: 20.0))
        
        if let disappearingAnimationLayer {
            disappearingAnimationLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                disappearingAnimationLayer.removeFromSuperlayer()
            })
            disappearingAnimationLayer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -10.0), duration: 0.2, removeOnCompletion: false, additive: true)
            disappearingAnimationLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
        }
    }
}

private final class WebAppEmojiStatusAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let presentationTheme: PresentationTheme
    private let botName: String
    
    private let textNode: ASTextNode
    private let iconBackgroundNode: ASImageNode
    private let iconAvatarNode: AvatarNode
    private let iconNameNode: ASTextNode
    private let iconAnimationNode: IconsNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(
        context: AccountContext,
        theme: AlertControllerTheme,
        ptheme: PresentationTheme,
        strings: PresentationStrings,
        accountPeer: EnginePeer,
        botName: String,
        icons: [TelegramMediaFile.Accessor],
        actions: [TextAlertAction]
    ) {
        self.strings = strings
        self.presentationTheme = ptheme
        self.botName = botName
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        self.iconBackgroundNode = ASImageNode()
        self.iconBackgroundNode.displaysAsynchronously = false
        self.iconBackgroundNode.image = generateStretchableFilledCircleImage(radius: 16.0, color: theme.separatorColor)
        
        self.iconAvatarNode = AvatarNode(font: avatarPlaceholderFont(size: 14.0))
        self.iconAvatarNode.setPeer(context: context, theme: ptheme, peer: accountPeer)

        self.iconNameNode = ASTextNode()
        self.iconNameNode.attributedText = NSAttributedString(string: accountPeer.compactDisplayTitle, font: Font.medium(15.0), textColor: theme.primaryColor)
        
        self.iconAnimationNode = IconsNode(context: context, files: icons)
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.iconBackgroundNode)
        self.addSubnode(self.iconAvatarNode)
        self.addSubnode(self.iconNameNode)
        self.addSubnode(self.iconAnimationNode)
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.updateTheme(theme)
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        let string = self.strings.WebApp_EmojiPermission_Text(self.botName, self.botName).string
        let attributedText = parseMarkdownIntoAttributedString(string, attributes: MarkdownAttributes(
            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor),
            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.primaryColor),
            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor),
            linkAttribute: { url in
                return ("URL", url)
            }
        ), textAlignment: .center)
        self.textNode.attributedText = attributedText
        
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
        
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var size = size
        size.width = min(size.width , 270.0)
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
                
        let iconSpacing: CGFloat = 6.0
        let iconSize = CGSize(width: 32.0, height: 32.0)
        let nameSize = self.iconNameNode.measure(size)
        let totalIconWidth = iconSize.width + iconSpacing + nameSize.width + 4.0 + iconSize.width
        
        let iconBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - totalIconWidth) / 2.0), y: origin.y), size: CGSize(width: totalIconWidth, height: iconSize.height))
        transition.updateFrame(node: self.iconBackgroundNode, frame: iconBackgroundFrame)
        transition.updateFrame(node: self.iconAvatarNode, frame: CGRect(origin: iconBackgroundFrame.origin, size: iconSize).insetBy(dx: 1.0, dy: 1.0))
        transition.updateFrame(node: self.iconNameNode, frame: CGRect(origin: CGPoint(x: iconBackgroundFrame.minX + iconSize.width + iconSpacing, y: iconBackgroundFrame.minY + floorToScreenPixels((iconBackgroundFrame.height - nameSize.height) / 2.0)), size: nameSize))
        
        self.iconAnimationNode.updateLayout(size: CGSize(width: 20.0, height: 20.0), theme: self.presentationTheme)
        self.iconAnimationNode.frame = CGRect(origin: CGPoint(x: iconBackgroundFrame.maxX - iconSize.width - 3.0, y: iconBackgroundFrame.minY), size: iconSize).insetBy(dx: 6.0, dy: 6.0)
        
        origin.y += iconSize.height + 16.0
        
        let textSize = self.textNode.measure(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
                case .horizontal:
                    minActionsWidth += actionTitleSize.width + actionTitleInsets
                case .vertical:
                    minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var contentWidth = minActionsWidth
        contentWidth = max(contentWidth, 234.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth + insets.left + insets.right
        let resultSize = CGSize(width: resultWidth, height: iconSize.height + textSize.height + actionsHeight + 16.0 + insets.top + insets.bottom)
        
        transition.updateFrame(node: self.actionNodesSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
                    case .vertical:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            switch effectiveActionLayout {
                case .horizontal:
                    if nodeIndex == self.actionNodes.count - 1 {
                        currentActionWidth = resultSize.width - actionOffset
                    } else {
                        currentActionWidth = actionWidth
                    }
                case .vertical:
                    currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        return resultSize
    }
}

func webAppEmojiStatusAlertController(
    context: AccountContext,
    accountPeer: EnginePeer,
    botName: String,
    icons: [TelegramMediaFile.Accessor],
    completion: @escaping (Bool) -> Void
) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    let strings = presentationData.strings
    
    var dismissImpl: ((Bool) -> Void)?
    var contentNode: WebAppEmojiStatusAlertContentNode?
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: strings.WebApp_EmojiPermission_Decline, action: {
        dismissImpl?(true)
        
        completion(false)
    }), TextAlertAction(type: .defaultAction, title: strings.WebApp_EmojiPermission_Allow, action: {
        dismissImpl?(true)
        
        completion(true)
    })]
    
    contentNode = WebAppEmojiStatusAlertContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, accountPeer: accountPeer, botName: botName, icons: icons, actions: actions)
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode!)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
