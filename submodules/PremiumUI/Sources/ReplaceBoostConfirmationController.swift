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
import Markdown
import CheckNode

private func generateBoostIcon(theme: PresentationTheme) -> UIImage? {
    if let image = UIImage(bundleImageName: "Premium/AvatarBoost") {
        let size = CGSize(width: image.size.width + 4.0, height: image.size.height + 4.0)
        return generateImage(size, contextGenerator: { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)
            if let cgImage = image.cgImage {
                context.draw(cgImage, in: CGRect(origin: CGPoint(x: 2.0, y: 2.0), size: image.size))
            }
            
            let lineWidth = 2.0 - UIScreenPixel
            context.setLineWidth(lineWidth)
            context.setStrokeColor(theme.actionSheet.opaqueItemBackgroundColor.cgColor)
            context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0 + UIScreenPixel, dy: lineWidth / 2.0 + UIScreenPixel))
        }, opaque: false)
    }
    return nil
}

private final class PreviousBoostNode: ASDisplayNode {
    let checkNode: InteractiveCheckNode
    let avatarNode: AvatarNode
    let labelNode: ImmediateTextNode
    
    var pressed: (PreviousBoostNode) -> Void = { _ in }
    
    init(context: AccountContext, theme: AlertControllerTheme, ptheme: PresentationTheme, peer: EnginePeer, badge: String?) {
        self.checkNode = InteractiveCheckNode(theme: CheckNodeTheme(backgroundColor: theme.accentColor, strokeColor: theme.contrastColor, borderColor: theme.controlBorderColor, overlayBorder: false, hasInset: false, hasShadow: false))
        self.checkNode.setSelected(false, animated: false)
       
        self.labelNode = ImmediateTextNode()
        self.labelNode.maximumNumberOfLines = 4
        self.labelNode.isUserInteractionEnabled = true
        self.labelNode.attributedText = NSAttributedString(string: peer.compactDisplayTitle, font: Font.semibold(13.0), textColor: theme.primaryColor)
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 13.0))
        
        super.init()
        
        self.addSubnode(self.checkNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.labelNode)
        
        self.avatarNode.setPeer(context: context, theme: ptheme, peer: peer)
        
        self.checkNode.valueChanged = { [weak self] value in
            if let self {
                if value {
                    self.pressed(self)
                }
            }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let checkSize = CGSize(width: 22.0, height: 22.0)
        let condensedSize = CGSize(width: size.width - 76.0, height: size.height)
        let avatarSize = CGSize(width: 30.0, height: 30.0)
        
        let labelSize = self.labelNode.updateLayout(condensedSize)
        transition.updateFrame(node: self.checkNode, frame: CGRect(origin: CGPoint(x: 12.0, y: -2.0), size: checkSize))
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: 46.0, y: -8.0), size: avatarSize))
        
        transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: 84.0, y: 0.0), size: labelSize))
        
        return CGSize(width: size.width, height: checkSize.height)
    }
    
    func setChecked(_ checked: Bool) {
        self.checkNode.setSelected(checked, animated: false)
    }
}

private final class ReplaceBoostConfirmationAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let text: String
    
    private let textNode: ASTextNode
    private let avatarNode: AvatarNode
    private let arrowNode: ASImageNode
    private let secondAvatarNode: AvatarNode
    private let iconNode: ASImageNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var boostNodes: [PreviousBoostNode] = []
    
    private var validLayout: CGSize?
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(context: AccountContext, theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, fromPeers: [EnginePeer], toPeer: EnginePeer, text: String, actions: [TextAlertAction]) {
        self.strings = strings
        self.text = text
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        
        self.secondAvatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = generateBoostIcon(theme: ptheme)
        
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
        
        var boostNodes: [PreviousBoostNode] = []
        if fromPeers.count > 1 {
            for peer in fromPeers {
                let boostNode = PreviousBoostNode(context: context, theme: theme, ptheme: ptheme, peer: peer, badge: nil)
                if boostNodes.isEmpty {
                    boostNode.setChecked(true)
                }
                boostNodes.append(boostNode)
            }
        }
        self.boostNodes = boostNodes
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.secondAvatarNode)
        self.addSubnode(self.iconNode)
    
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        for boostNode in self.boostNodes {
            boostNode.pressed = { [weak self] sender in
                if let self {
                    for node in self.boostNodes {
                        node.setChecked(node === sender)
                    }
                }
            }
            self.addSubnode(boostNode)
        }
        
        self.updateTheme(theme)
        
        self.avatarNode.setPeer(context: context, theme: ptheme, peer: fromPeers.first!)
        self.secondAvatarNode.setPeer(context: context, theme: ptheme, peer: toPeer)
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.textNode.attributedText = parseMarkdownIntoAttributedString(self.text, attributes: MarkdownAttributes(
            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor),
            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.primaryColor),
            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor),
            linkAttribute: { url in
                return ("URL", url)
            }
        ), textAlignment: .center)
        self.arrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Peer Info/AlertArrow"), color: theme.secondaryColor)
        
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
        size.width = min(size.width, 270.0)
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        
        let avatarSize = CGSize(width: 60.0, height: 60.0)
        self.avatarNode.updateSize(size: avatarSize)
        
        let avatarFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - avatarSize.width) / 2.0) - 44.0, y: origin.y), size: avatarSize)
        transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
        
        if let arrowImage = self.arrowNode.image {
            let arrowFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - arrowImage.size.width) / 2.0), y: origin.y + floorToScreenPixels((avatarSize.height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
            transition.updateFrame(node: self.arrowNode, frame: arrowFrame)
        }
        
        let secondAvatarFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - avatarSize.width) / 2.0) + 44.0, y: origin.y), size: avatarSize)
        transition.updateFrame(node: self.secondAvatarNode, frame: secondAvatarFrame)
        
        if let icon = self.iconNode.image {
            let iconFrame = CGRect(origin: CGPoint(x: avatarFrame.maxX + 4.0 - icon.size.width, y: avatarFrame.maxY + 4.0 - icon.size.height), size: icon.size)
            transition.updateFrame(node: self.iconNode, frame: iconFrame)
        }
        
        origin.y += avatarSize.height + 10.0
        
        var entriesHeight: CGFloat = 0.0
        let textSize = self.textNode.measure(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height + 10.0
        
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
        
        let contentWidth = max(size.width, minActionsWidth)
        
        if !self.boostNodes.isEmpty {
            origin.y += 17.0
            for boostNode in self.boostNodes {
                let boostSize = boostNode.updateLayout(size: size, transition: transition)
                transition.updateFrame(node: boostNode, frame: CGRect(origin: CGPoint(x: 36.0, y: origin.y), size: boostSize))
                
                entriesHeight += boostSize.height + 20.0
                origin.y += boostSize.height + 20.0
            }
        }
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultSize = CGSize(width: contentWidth, height: avatarSize.height + textSize.height + entriesHeight + actionsHeight + 16.0 + insets.top + insets.bottom)
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

func replaceBoostConfirmationController(context: AccountContext, fromPeers: [EnginePeer], toPeer: EnginePeer, commit: @escaping () -> Void) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let text = strings.ChannelBoost_ReplaceBoost(fromPeers.first!.compactDisplayTitle, toPeer.compactDisplayTitle).string
    
    var dismissImpl: ((Bool) -> Void)?
    var contentNode: ReplaceBoostConfirmationAlertContentNode?
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: strings.ChannelBoost_Replace, action: {
        dismissImpl?(true)
        commit()
    })]
    
    contentNode = ReplaceBoostConfirmationAlertContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: strings, fromPeers: fromPeers, toPeer: toPeer, text: text, actions: actions)
    
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
