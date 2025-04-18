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
import PhotoResources
import CheckNode
import Markdown

private let textFont = Font.regular(13.0)
private let boldTextFont = Font.semibold(13.0)

private func formattedText(_ text: String, color: UIColor, textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    return parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: color), bold: MarkdownAttributeSet(font: boldTextFont, textColor: color), link: MarkdownAttributeSet(font: textFont, textColor: color), linkAttribute: { _ in return nil}), textAlignment: textAlignment)
}

private final class BrowserExceptionDomainAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let domain: String
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    
    private let allowWriteCheckNode: InteractiveCheckNode
    private let allowWriteLabelNode: ASTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    private var iconDisposable: Disposable?
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    var allowWriteAccess: Bool = true {
        didSet {
            self.allowWriteCheckNode.setSelected(self.allowWriteAccess, animated: true)
        }
    }
    
    init(account: Account, theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, domain: String, requestWriteAccess: Bool, actions: [TextAlertAction]) {
        self.strings = strings
        self.domain = domain
          
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 0
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
       
        self.allowWriteCheckNode = InteractiveCheckNode(theme: CheckNodeTheme(backgroundColor: theme.accentColor, strokeColor: theme.contrastColor, borderColor: theme.controlBorderColor, overlayBorder: false, hasInset: false, hasShadow: false))
        self.allowWriteCheckNode.setSelected(true, animated: false)
        self.allowWriteLabelNode = ASTextNode()
        self.allowWriteLabelNode.maximumNumberOfLines = 4
        self.allowWriteLabelNode.isUserInteractionEnabled = true
       
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
        
        if requestWriteAccess {
            self.addSubnode(self.allowWriteCheckNode)
            self.addSubnode(self.allowWriteLabelNode)
        }
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.allowWriteCheckNode.valueChanged = { [weak self] value in
            if let strongSelf = self {
                strongSelf.allowWriteAccess = !strongSelf.allowWriteAccess
            }
        }
        
        self.updateTheme(theme)
    }
    
    deinit {
        self.iconDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.allowWriteLabelNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.allowWriteTap(_:))))
    }
    
    @objc private func allowWriteTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if self.allowWriteCheckNode.isUserInteractionEnabled {
            self.allowWriteAccess = !self.allowWriteAccess
        }
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: "Open in Browser", font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: "Do you want to open this link in your default browser?", font: Font.regular(13.0), textColor: theme.primaryColor, paragraphAlignment: .center)
                
        self.allowWriteLabelNode.attributedText = formattedText("Always open links from **\(self.domain)** in browser", color: theme.primaryColor)
        
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
        
        let titleSize = self.titleNode.measure(size)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 13.0
        
        let textSize = self.textNode.measure(size)
        var textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize)
        origin.y += textSize.height
        
        var entriesHeight: CGFloat = 0.0
        
        if self.allowWriteLabelNode.supernode != nil {
            origin.y += 16.0
            entriesHeight += 16.0
            
            let checkSize = CGSize(width: 22.0, height: 22.0)
            let condensedSize = CGSize(width: size.width - 76.0, height: size.height)
            
            let allowWriteSize = self.allowWriteLabelNode.measure(condensedSize)
            transition.updateFrame(node: self.allowWriteLabelNode, frame: CGRect(origin: CGPoint(x: 46.0, y: origin.y), size: allowWriteSize))
            transition.updateFrame(node: self.allowWriteCheckNode, frame: CGRect(origin: CGPoint(x: 12.0, y: origin.y - 2.0), size: checkSize))
            origin.y += allowWriteSize.height
            entriesHeight += allowWriteSize.height
        }
        
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
        
        var contentWidth = max(textSize.width, minActionsWidth)
        contentWidth = max(contentWidth, 234.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth + insets.left + insets.right
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + textSize.height + entriesHeight + actionsHeight + 17.0 + insets.top + insets.bottom)
        
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

        textFrame.origin.x = floorToScreenPixels((resultSize.width - textFrame.width) / 2.0)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        return resultSize
    }
}

public func browserExceptionDomainAlertController(context: AccountContext, domain: String, completion: @escaping (Bool) -> Void) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    let strings = presentationData.strings
    
    var dismissImpl: ((Bool) -> Void)?
    var getContentNodeImpl: (() -> BrowserExceptionDomainAlertContentNode?)?
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: "Continue", action: {
        if let allowWriteAccess = getContentNodeImpl?()?.allowWriteAccess {
            completion(allowWriteAccess)
        } else {
            completion(false)
        }
        dismissImpl?(true)
    })]
    
    let contentNode = BrowserExceptionDomainAlertContentNode(account: context.account, theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, domain: domain, requestWriteAccess: true, actions: actions)
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
