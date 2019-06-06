import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private func generateIconImage(theme: AlertControllerTheme) -> UIImage? {
    return UIImage(bundleImageName: "Call List/AlertIcon")
//    return generateImage(frame.size, contextGenerator: { size, context in
//        let bounds = CGRect(origin: CGPoint(), size: size)
//        context.clear(bounds)
//
//        let relativeFrame = CGRect(x: -frame.minX, y: frame.minY - background.size.height + frame.size.height
//            , width: background.size.width, height: background.size.height)
//
//        context.beginPath()
//        context.addEllipse(in: bounds)
//        context.clip()
//
//        context.setAlpha(0.8)
//        context.draw(background.foregroundImage.cgImage!, in: relativeFrame)
//
//        if highlighted {
//            context.setFillColor(UIColor(white: 1.0, alpha: 0.65).cgColor)
//            context.fillEllipse(in: bounds)
//        }
//
//        context.setAlpha(1.0)
//        context.textMatrix = .identity
//
//        let titleFont: UIFont
//        let subtitleFont: UIFont
//        let titleOffset: CGFloat
//        let subtitleOffset: CGFloat
//        if size.width > 80.0 {
//            titleFont = largeTitleFont
//            subtitleFont = largeSubtitleFont
//            if subtitle.isEmpty {
//                titleOffset = -18.0
//            } else {
//                titleOffset = -11.0
//            }
//            subtitleOffset = -54.0
//        } else {
//            titleFont = regularTitleFont
//            subtitleFont = regularSubtitleFont
//            if subtitle.isEmpty {
//                titleOffset = -17.0
//            } else {
//                titleOffset = -10.0
//            }
//            subtitleOffset = -48.0
//        }
//
//        let titlePath = CGMutablePath()
//        titlePath.addRect(bounds.offsetBy(dx: 0.0, dy: titleOffset))
//        let titleString = NSAttributedString(string: title, font: titleFont, textColor: .white, paragraphAlignment: .center)
//        let titleFramesetter = CTFramesetterCreateWithAttributedString(titleString as CFAttributedString)
//        let titleFrame = CTFramesetterCreateFrame(titleFramesetter, CFRangeMake(0, titleString.length), titlePath, nil)
//        CTFrameDraw(titleFrame, context)
//
//        if !subtitle.isEmpty {
//            let subtitlePath = CGMutablePath()
//            subtitlePath.addRect(bounds.offsetBy(dx: 0.0, dy: subtitleOffset))
//            let subtitleString = NSAttributedString(string: subtitle, font: subtitleFont, textColor: .white, paragraphAlignment: .center)
//            let subtitleFramesetter = CTFramesetterCreateWithAttributedString(subtitleString as CFAttributedString)
//            let subtitleFrame = CTFramesetterCreateFrame(subtitleFramesetter, CFRangeMake(0, subtitleString.length), subtitlePath, nil)
//            CTFrameDraw(subtitleFrame, context)
//        }
//    })
}

private final class CallSuggestTabContentActionNode: HighlightableButtonNode {
    private let backgroundNode: ASDisplayNode
    
    let action: TextAlertAction
    
    init(theme: AlertControllerTheme, action: TextAlertAction) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.alpha = 0.0
        
        self.action = action
        
        super.init()
        
        self.titleNode.maximumNumberOfLines = 2
        
        self.highligthedChanged = { [weak self] value in
            if let strongSelf = self {
                if value {
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 1.0
                } else if !strongSelf.backgroundNode.alpha.isZero {
                    strongSelf.backgroundNode.alpha = 0.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                }
            }
        }
        
        self.updateTheme(theme)
    }
    
    func updateTheme(_ theme: AlertControllerTheme) {
        self.backgroundNode.backgroundColor = theme.highlightedItemColor
        
        var font = Font.regular(17.0)
        var color = theme.accentColor
        switch self.action.type {
            case .defaultAction, .genericAction:
                break
            case .destructiveAction:
                color = theme.destructiveColor
        }
        switch self.action.type {
            case .defaultAction:
                font = Font.semibold(17.0)
            case .destructiveAction, .genericAction:
                break
        }
        self.setAttributedTitle(NSAttributedString(string: self.action.title, font: font, textColor: color, paragraphAlignment: .center), for: [])
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc func pressed() {
        self.action.action()
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
    }
}

private final class CallSuggestTabAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private let iconNode: ASImageNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [CallSuggestTabContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, actions: [TextAlertAction]) {
        self.strings = strings
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 2
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        self.iconNode = ASImageNode()
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
        self.actionNodes = actions.map { action -> CallSuggestTabContentActionNode in
            return CallSuggestTabContentActionNode(theme: theme, action: action)
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
        self.addSubnode(self.iconNode)
        
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
        self.titleNode.attributedText = NSAttributedString(string: strings.Calls_CallTabTitle, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: strings.Calls_CallTabDescription, font: Font.regular(13.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        self.iconNode.image = generateIconImage(theme: theme)
        
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
        
        var iconSize = CGSize()
        if let icon = self.iconNode.image {
            iconSize = icon.size
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) / 2.0), y: origin.y), size: iconSize))
            origin.y += iconSize.height + 16.0
        }
        
        let textSize = self.textNode.measure(size)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.measure(CGSize(width: maxActionWidth, height: actionButtonHeight))
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
        
        var contentWidth = max(titleSize.width, minActionsWidth)
        contentWidth = max(contentWidth, 234.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth + insets.left + insets.right
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + iconSize.height + textSize.height + actionsHeight + 34.0 + insets.top + insets.bottom)
        
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

func callSuggestTabController(sharedContext: SharedAccountContext) -> AlertController {
    let presentationData = sharedContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    let strings = presentationData.strings
    
    var dismissImpl: ((Bool) -> Void)?
    var contentNode: CallSuggestTabAlertContentNode?
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_NotNow, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Calls_AddTab, action: {
        dismissImpl?(true)
        let _ = updateCallListSettingsInteractively(accountManager: sharedContext.accountManager, {
            $0.withUpdatedShowTab(true)
        }).start()
    })]
    
    contentNode = CallSuggestTabAlertContentNode(theme: AlertControllerTheme(presentationTheme: theme), ptheme: theme, strings: strings, actions: actions)
    
    let controller = AlertController(theme: AlertControllerTheme(presentationTheme: theme), contentNode: contentNode!)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
