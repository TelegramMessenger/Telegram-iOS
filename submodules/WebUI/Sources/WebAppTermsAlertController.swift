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
import TextFormat

private let textFont = Font.regular(13.0)
private let boldTextFont = Font.semibold(13.0)

private func formattedText(_ text: String, fontSize: CGFloat, color: UIColor, linkColor: UIColor, textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    return parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: Font.regular(fontSize), textColor: color), bold: MarkdownAttributeSet(font: Font.semibold(fontSize), textColor: color), link: MarkdownAttributeSet(font: Font.regular(fontSize), textColor: linkColor), linkAttribute: { _ in return (TelegramTextAttributes.URL, "") }), textAlignment: textAlignment)
}

private final class WebAppTermsAlertContentNode: AlertContentNode, UIGestureRecognizerDelegate {
    private let strings: PresentationStrings
    private let title: String
    private let text: String
    private let additionalText: String?
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let additionalTextNode: ImmediateTextNode
        
    private let acceptTermsCheckNode: InteractiveCheckNode
    private let acceptTermsLabelNode: ImmediateTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
        
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    var acceptedTerms: Bool = false {
        didSet {
            self.acceptTermsCheckNode.setSelected(self.acceptedTerms, animated: true)
            if let firstAction = self.actionNodes.first {
                firstAction.actionEnabled = self.acceptedTerms
            }
        }
    }
    
    var openTerms: () -> Void = {}
    
    init(context: AccountContext, theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, title: String, text: String, additionalText: String?, actions: [TextAlertAction]) {
        self.strings = strings
        self.title = title
        self.text = text
        self.additionalText = additionalText
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.displaysAsynchronously = false
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        self.additionalTextNode = ImmediateTextNode()
        self.additionalTextNode.maximumNumberOfLines = 0
        self.additionalTextNode.displaysAsynchronously = false
        self.additionalTextNode.lineSpacing = 0.1
        self.additionalTextNode.textAlignment = .center
        
        self.acceptTermsCheckNode = InteractiveCheckNode(theme: CheckNodeTheme(backgroundColor: theme.accentColor, strokeColor: theme.contrastColor, borderColor: theme.controlBorderColor, overlayBorder: false, hasInset: false, hasShadow: false))
        self.acceptTermsLabelNode = ImmediateTextNode()
        self.acceptTermsLabelNode.maximumNumberOfLines = 4
       
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
        self.addSubnode(self.additionalTextNode)

        self.addSubnode(self.acceptTermsCheckNode)
        self.addSubnode(self.acceptTermsLabelNode)
    
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
                
        self.acceptTermsCheckNode.valueChanged = { [weak self] value in
            if let strongSelf = self {
                strongSelf.acceptedTerms = !strongSelf.acceptedTerms
            }
        }
        
        self.acceptTermsLabelNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.acceptTermsLabelNode.tapAttributeAction = { [weak self] attributes, _ in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                self?.openTerms()
            }
        }
        
        self.updateTheme(theme)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.acceptTap(_:)))
        tapGesture.delegate = self
        self.view.addGestureRecognizer(tapGesture)
        
        if let firstAction = self.actionNodes.first {
            firstAction.actionEnabled = false
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: self.acceptTermsLabelNode.view)
        if self.acceptTermsLabelNode.bounds.contains(location) {
            return true
        }
        return false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        
        if let (_, attributes) = self.acceptTermsLabelNode.attributesAtPoint(self.view.convert(point, to: self.acceptTermsLabelNode.view)) {
            if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] == nil {
                return self.view
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    @objc private func acceptTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: self.acceptTermsLabelNode.view)
        if self.acceptTermsCheckNode.isUserInteractionEnabled {
            if let attributes = self.acceptTermsLabelNode.attributesAtPoint(location)?.1 {
                if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] != nil {
                    return
                }
            }
            self.acceptedTerms = !self.acceptedTerms
        }
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.semibold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        self.textNode.attributedText = formattedText(self.text, fontSize: 13.0, color: theme.primaryColor, linkColor: theme.accentColor, textAlignment: .center)
        if let additionalText = self.additionalText {
            self.additionalTextNode.attributedText = formattedText(additionalText, fontSize: 13.0, color: theme.primaryColor, linkColor: theme.accentColor, textAlignment: .center)
        } else {
            self.additionalTextNode.attributedText = nil
        }

        let attributedAgreeText = parseMarkdownIntoAttributedString(
            self.strings.WebApp_DisclaimerAgree,
            attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: theme.primaryColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: theme.primaryColor),
                link: MarkdownAttributeSet(font: textFont, textColor: theme.accentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
        )
        
        self.acceptTermsLabelNode.attributedText = attributedAgreeText
        self.acceptTermsLabelNode.linkHighlightColor = theme.accentColor.withAlphaComponent(0.2)
        
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
        origin.y += titleSize.height + 4.0
        
        var entriesHeight: CGFloat = 0.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - 48.0, height: size.height))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height
        
        if self.acceptTermsLabelNode.supernode != nil {
            origin.y += 21.0
            entriesHeight += 21.0
            
            let checkSize = CGSize(width: 22.0, height: 22.0)
            let condensedSize = CGSize(width: size.width - 76.0, height: size.height)
            
            let spacing: CGFloat = 12.0
            let acceptTermsSize = self.acceptTermsLabelNode.updateLayout(condensedSize)
            let acceptTermsTotalWidth = checkSize.width + spacing + acceptTermsSize.width
            let acceptTermsOriginX = floorToScreenPixels((size.width - acceptTermsTotalWidth) / 2.0)
            
            transition.updateFrame(node: self.acceptTermsCheckNode, frame: CGRect(origin: CGPoint(x: acceptTermsOriginX, y: origin.y - 3.0), size: checkSize))
            transition.updateFrame(node: self.acceptTermsLabelNode, frame: CGRect(origin: CGPoint(x: acceptTermsOriginX + checkSize.width + spacing, y: origin.y), size: acceptTermsSize))
            origin.y += acceptTermsSize.height
            entriesHeight += acceptTermsSize.height
            origin.y += 21.0
        }
        
        let additionalTextSize = self.additionalTextNode.updateLayout(CGSize(width: size.width - 48.0, height: size.height))
        transition.updateFrame(node: self.additionalTextNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - additionalTextSize.width) / 2.0), y: origin.y), size: additionalTextSize))
        origin.y += additionalTextSize.height
        if additionalTextSize.height > 0.0 {
            entriesHeight += 20.0
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
        
        let resultSize = CGSize(width: contentWidth, height: titleSize.height + textSize.height + additionalTextSize.height + entriesHeight + actionsHeight + 3.0 + insets.top + insets.bottom)
        
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

public func webAppTermsAlertController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    bot: AttachMenuBot,
    completion: @escaping (Bool) -> Void
) -> AlertController {
    let theme = defaultDarkColorPresentationTheme
    let presentationData: PresentationData
    if let updatedPresentationData {
        presentationData = updatedPresentationData.initial
    } else {
        presentationData = context.sharedContext.currentPresentationData.with { $0 }
    }
    let strings = presentationData.strings
    
    var dismissImpl: ((Bool) -> Void)?
    let actions: [TextAlertAction] = [TextAlertAction(type: .defaultAction, title: presentationData.strings.WebApp_DisclaimerContinue, action: {
        completion(true)
        dismissImpl?(true)
    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    })]
    
    let title = presentationData.strings.WebApp_DisclaimerTitle
    let text = presentationData.strings.WebApp_DisclaimerText
    let additionalText: String? = nil
    
    let contentNode = WebAppTermsAlertContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, title: title, text: text, additionalText: additionalText, actions: actions)
    contentNode.openTerms = {
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: presentationData.strings.WebApp_Disclaimer_URL, forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {
        })
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
