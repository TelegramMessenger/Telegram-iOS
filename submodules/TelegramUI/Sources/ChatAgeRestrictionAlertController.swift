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
import CheckNode
import Markdown

private let textFont = Font.regular(13.0)
private let boldTextFont = Font.semibold(13.0)

private func formattedText(_ text: String, color: UIColor, textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    return parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: color), bold: MarkdownAttributeSet(font: boldTextFont, textColor: color), link: MarkdownAttributeSet(font: textFont, textColor: color), linkAttribute: { _ in return nil}), textAlignment: textAlignment)
}

private final class ChatAgeRestrictionAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let title: String
    private let text: String
    
    private let titleNode: ImmediateTextNode
    private let textNode: ASTextNode
        
    private let alwaysCheckNode: InteractiveCheckNode
    private let alwaysLabelNode: ASTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
        
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    var alwaysShow: Bool = false {
        didSet {
            self.alwaysCheckNode.setSelected(self.alwaysShow, animated: true)
        }
    }
    
    init(context: AccountContext, theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, title: String, text: String, actions: [TextAlertAction]) {
        self.strings = strings
        self.title = title
        self.text = text
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.textAlignment = .center
        
        self.textNode = ASTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.1
                        
        self.alwaysCheckNode = InteractiveCheckNode(theme: CheckNodeTheme(backgroundColor: theme.accentColor, strokeColor: theme.contrastColor, borderColor: theme.controlBorderColor, overlayBorder: false, hasInset: false, hasShadow: false))
        self.alwaysLabelNode = ASTextNode()
        self.alwaysLabelNode.maximumNumberOfLines = 2
        self.alwaysLabelNode.isUserInteractionEnabled = true
       
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
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
                
        self.addSubnode(self.alwaysCheckNode)
        self.addSubnode(self.alwaysLabelNode)
        
    
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.alwaysCheckNode.valueChanged = { [weak self] value in
            if let strongSelf = self {
                strongSelf.alwaysShow = !strongSelf.alwaysShow
            }
        }
        
        self.updateTheme(theme)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.alwaysLabelNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.alwaysTap(_:))))
    }
    
    @objc private func alwaysTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if self.alwaysCheckNode.isUserInteractionEnabled {
            self.alwaysShow = !self.alwaysShow
        }
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.semibold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: self.text, font: Font.regular(13.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        
        self.alwaysLabelNode.attributedText = formattedText(self.strings.SensitiveContent_ShowAlways, color: theme.primaryColor)
        
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
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 17.0)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 6.0
        
        var entriesHeight: CGFloat = 0.0
        
        let textSize = self.textNode.measure(CGSize(width: size.width - 32.0, height: size.height))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height
        
        if self.alwaysLabelNode.supernode != nil {
            origin.y += 21.0
            entriesHeight += 21.0
            
            let checkSize = CGSize(width: 22.0, height: 22.0)
            let condensedSize = CGSize(width: size.width - 76.0, height: size.height)
            
            let alwaysSize = self.alwaysLabelNode.measure(condensedSize)
            let totalWidth = checkSize.width + alwaysSize.width + 12.0
            let originX = floorToScreenPixels((size.width - totalWidth) / 2.0)
            transition.updateFrame(node: self.alwaysLabelNode, frame: CGRect(origin: CGPoint(x: originX + checkSize.width + 12.0, y: origin.y), size: alwaysSize))
            transition.updateFrame(node: self.alwaysCheckNode, frame: CGRect(origin: CGPoint(x: originX, y: origin.y - 2.0), size: checkSize))
            origin.y += alwaysSize.height
            entriesHeight += alwaysSize.height
        }
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.vertical
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
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultSize = CGSize(width: contentWidth, height: titleSize.height + textSize.height + entriesHeight + actionsHeight + 8.0 + insets.top + insets.bottom)
        
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

public func chatAgeRestrictionAlertController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, completion: @escaping (Bool) -> Void) -> AlertController {
    let theme = defaultDarkColorPresentationTheme
    let presentationData: PresentationData
    if let updatedPresentationData {
        presentationData = updatedPresentationData.initial
    } else {
        presentationData = context.sharedContext.currentPresentationData.with { $0 }
    }
    let strings = presentationData.strings
    
    var dismissImpl: ((Bool) -> Void)?
    var getContentNodeImpl: (() -> ChatAgeRestrictionAlertContentNode?)?
    let actions: [TextAlertAction] = [TextAlertAction(type: .defaultAction, title: strings.SensitiveContent_ViewAnyway, action: {
        if let alwaysShow = getContentNodeImpl?()?.alwaysShow {
            completion(alwaysShow)
        } else {
            completion(false)
        }
        dismissImpl?(true)
    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    })]
    
    let title = strings.SensitiveContent_Title
    let text = strings.SensitiveContent_Text
    
    let contentNode = ChatAgeRestrictionAlertContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, title: title, text: text, actions: actions)
    getContentNodeImpl = { [weak contentNode] in
        return contentNode
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
