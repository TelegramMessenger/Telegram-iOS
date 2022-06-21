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

private final class WebAppAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    private let peerName: String
    private let peerIcon: TelegramMediaFile?
    
    private let textNode: ASTextNode
    private let appIconNode: ASImageNode
    private let iconNode: ASImageNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    private var iconDisposable: Disposable?
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(account: Account, theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, peerName: String, icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile], actions: [TextAlertAction]) {
        self.strings = strings
        self.peerName = peerName
        
        if let icon = icons[.iOSStatic] {
            self.peerIcon = icon
        } else if let icon = icons[.default] {
            self.peerIcon = icon
        } else {
            self.peerIcon = nil
        }
        
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
       
        self.appIconNode = ASImageNode()
        self.appIconNode.displaysAsynchronously = false
        self.appIconNode.displayWithoutProcessing = true
       
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
       
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
        self.addSubnode(self.appIconNode)
        self.addSubnode(self.iconNode)
    
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.updateTheme(theme)
        
        if let peerIcon = self.peerIcon {
            let _ = freeMediaFileInteractiveFetched(account: account, fileReference: .standalone(media: peerIcon)).start()
            self.iconDisposable = (svgIconImageFile(account: account, fileReference: .standalone(media: peerIcon))
            |> deliverOnMainQueue).start(next: { [weak self] transform in
                if let strongSelf = self {
                    let availableSize = CGSize(width: 48.0, height: 48.0)
                    let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: availableSize, boundingSize: availableSize, intrinsicInsets: UIEdgeInsets())
                    let drawingContext = transform(arguments)
                    let image = drawingContext?.generateImage()?.withRenderingMode(.alwaysTemplate)
                    strongSelf.appIconNode.image = generateTintedImage(image: image, color: theme.accentColor, backgroundColor: nil)
                }
            })
        }
    }
    
    deinit {
        self.iconDisposable?.dispose()
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.textNode.attributedText = NSAttributedString(string: strings.WebApp_AddToAttachmentText(self.peerName).string, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        
        self.appIconNode.image = generateTintedImage(image: self.appIconNode.image, color: theme.accentColor)
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Attach Menu/BotPlus"), color: theme.accentColor)
        
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
        
        var iconSize = CGSize()
        var iconFrame = CGRect()
        if let icon = self.iconNode.image {
            iconSize = icon.size
            iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) / 2.0), y: origin.y), size: iconSize)
            origin.y += iconSize.height + 16.0
        }
        
        let textSize = self.textNode.measure(size)
        var textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize)
        
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
        let resultSize = CGSize(width: resultWidth, height: iconSize.height + textSize.height + actionsHeight + 17.0 + insets.top + insets.bottom)
        
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
        
        iconFrame.origin.x = floorToScreenPixels((resultSize.width - iconFrame.width) / 2.0) + 19.0
        
        transition.updateFrame(node: self.appIconNode, frame: CGRect(x: iconFrame.minX - 50.0, y: iconFrame.minY + 3.0, width: 42.0, height: 42.0))
        transition.updateFrame(node: self.iconNode, frame: iconFrame)
       
        textFrame.origin.x = floorToScreenPixels((resultSize.width - textFrame.width) / 2.0)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        return resultSize
    }
}

public func addWebAppToAttachmentController(context: AccountContext, peerName: String, icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile], completion: @escaping () -> Void) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    let strings = presentationData.strings
    
    var dismissImpl: ((Bool) -> Void)?
    var contentNode: WebAppAlertContentNode?
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.WebApp_AddToAttachmentAdd, action: {
        dismissImpl?(true)
      
        completion()
    })]
    
    contentNode = WebAppAlertContentNode(account: context.account, theme: AlertControllerTheme(presentationData: presentationData), ptheme: theme, strings: strings, peerName: peerName, icons: icons, actions: actions)
    
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
