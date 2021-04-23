import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext
import UrlEscaping

private final class VoiceChatCameraPreviewAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let title: String
    private let text: String
    
    private let backgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    private let hapticFeedback = HapticFeedback()
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, actions: [TextAlertAction], title: String, text: String) {
        self.strings = strings
        self.title = title
        self.text = text
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.backgroundColor = UIColor(rgb: 0x161619)
        
        self.maskNode = ASImageNode()
        self.maskNode.displaysAsynchronously = false
        self.maskNode.contentMode = .scaleToFill
        self.maskNode.image = generateImage(CGSize(width: 300.0, height: 400.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            
            context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.3).cgColor)
            context.fill(bounds)
            
            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(x: 27.0, y: 37.0, width: 246.0, height: 300.0))
        })
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 2
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 8
                
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
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.actionNodesSeparator)
                
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.backgroundNode.addSubnode(self.maskNode)
        
        self.updateTheme(theme)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: self.text, font: Font.regular(13.0), textColor: theme.primaryColor, paragraphAlignment: .center)

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
        size.width = min(size.width, 300.0)
        let measureSize = CGSize(width: size.width - 16.0 * 2.0, height: CGFloat.greatestFiniteMagnitude)
        
        let hadValidLayout = self.validLayout != nil
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 18.0)
        let spacing: CGFloat = 3.0
        
        let videoHeight: CGFloat = 400.0
        origin.y += videoHeight
        
        let titleSize = self.titleNode.measure(measureSize)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 4.0
        
        let textSize = self.textNode.measure(measureSize)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height + 6.0
        
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
        
        var contentWidth = max(titleSize.width, minActionsWidth)
        contentWidth = max(contentWidth, 300.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + textSize.height + spacing + videoHeight + spacing + actionsHeight + insets.top + insets.bottom)
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: resultWidth, height: videoHeight)))
        transition.updateFrame(node: self.maskNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: resultWidth, height: videoHeight)))
        
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
        
        if !hadValidLayout {
            Queue.mainQueue().after(0.1) {
                self.maskNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.maskNode.layer.animateSpring(from: 1.4 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, initialVelocity: 0.0, damping: 104.0)
            }
        }
        
        return resultSize
    }
}

func voiceChatCameraPreviewController(sharedContext: SharedAccountContext, account: Account, forceTheme: PresentationTheme?, title: String, text: String, apply: @escaping () -> Void) -> AlertController {
    var presentationData = sharedContext.currentPresentationData.with { $0 }
    if let forceTheme = forceTheme {
        presentationData = presentationData.withUpdated(theme: forceTheme)
    }
    
    var dismissImpl: ((Bool) -> Void)?
    var applyImpl: (() -> Void)?
    
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.VoiceChat_VideoPreviewShare, action: {
        applyImpl?()
    })]
    
    let contentNode = VoiceChatCameraPreviewAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, actions: actions, title: title, text: text)
    applyImpl = { [weak contentNode] in
        guard let contentNode = contentNode else {
            return
        }
        dismissImpl?(true)
        
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = sharedContext.presentationData.start(next: { [weak controller, weak contentNode] presentationData in
        var presentationData = presentationData
        if let forceTheme = forceTheme {
            presentationData = presentationData.withUpdated(theme: forceTheme)
        }
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
    })
    controller.dismissed = {
        presentationDataDisposable.dispose()
    }
    dismissImpl = { [weak controller, weak contentNode] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
