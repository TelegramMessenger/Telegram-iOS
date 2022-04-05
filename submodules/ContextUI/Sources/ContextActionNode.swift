import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SwiftSignalKit

public enum ContextActionSibling {
    case none
    case item
    case separator
}

public protocol ContextActionNodeProtocol: ASDisplayNode {
    func setIsHighlighted(_ value: Bool)
    func performAction()
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol
    var isActionEnabled: Bool { get }
}

public final class ContextActionNode: ASDisplayNode, ContextActionNodeProtocol {
    private var presentationData: PresentationData
    private(set) var action: ContextMenuActionItem
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    private let requestLayout: () -> Void
    private let requestUpdateAction: (AnyHashable, ContextMenuActionItem) -> Void
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let statusNode: ImmediateTextNode?
    private let iconNode: ASImageNode
    private let badgeBackgroundNode: ASImageNode
    private let badgeTextNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private var iconDisposable: Disposable?
    
    private var pointerInteraction: PointerInteraction?

    public var isActionEnabled: Bool {
        return true
    }
    
    public init(presentationData: PresentationData, action: ContextMenuActionItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void, requestLayout: @escaping () -> Void, requestUpdateAction: @escaping (AnyHashable, ContextMenuActionItem) -> Void) {
        self.presentationData = presentationData
        self.action = action
        self.getController = getController
        self.actionSelected = actionSelected
        self.requestLayout = requestLayout
        self.requestUpdateAction = requestUpdateAction
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        let smallTextFont = Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0))
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        let textColor: UIColor
        switch action.textColor {
        case .primary:
            textColor = presentationData.theme.contextMenu.primaryColor
        case .destructive:
            textColor = presentationData.theme.contextMenu.destructiveColor
        case .disabled:
            textColor = presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.4)
        }
        
        let titleFont: UIFont
        switch action.textFont {
        case .regular:
            titleFont = textFont
        case .small:
            titleFont = smallTextFont
        case let .custom(customFont):
            titleFont = customFont
        }
        
        let subtitleFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0)
        
        self.textNode.attributedText = NSAttributedString(string: action.text, font: titleFont, textColor: textColor)
        
        switch action.textLayout {
        case .singleLine:
            self.textNode.maximumNumberOfLines = 1
            self.statusNode = nil
        case .twoLinesMax:
            self.textNode.maximumNumberOfLines = 2
            self.statusNode = nil
        case let .secondLineWithValue(value):
            self.textNode.maximumNumberOfLines = 1
            let statusNode = ImmediateTextNode()
            statusNode.isAccessibilityElement = false
            statusNode.isUserInteractionEnabled = false
            statusNode.displaysAsynchronously = false
            statusNode.attributedText = NSAttributedString(string: value, font: subtitleFont, textColor: presentationData.theme.contextMenu.secondaryColor)
            statusNode.maximumNumberOfLines = 1
            self.statusNode = statusNode
        case .multiline:
            self.textNode.maximumNumberOfLines = 0
            self.statusNode = nil
        }
        
        self.iconNode = ASImageNode()
        self.iconNode.isAccessibilityElement = false
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        if action.iconSource == nil {
            self.iconNode.image = action.icon(presentationData.theme)
        }
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.isAccessibilityElement = false
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.displayWithoutProcessing = true
        self.badgeBackgroundNode.isUserInteractionEnabled = false
        
        self.badgeTextNode = ImmediateTextNode()
        if let badge = action.badge {
            let badgeFillColor: UIColor
            let badgeForegroundColor: UIColor
            switch badge.color {
            case .accent:
                badgeForegroundColor = presentationData.theme.contextMenu.badgeForegroundColor
                badgeFillColor = presentationData.theme.contextMenu.badgeFillColor
            case .inactive:
                badgeForegroundColor = presentationData.theme.contextMenu.badgeInactiveForegroundColor
                badgeFillColor = presentationData.theme.contextMenu.badgeInactiveFillColor
            }
            self.badgeBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: badgeFillColor)
            self.badgeTextNode.attributedText = NSAttributedString(string: badge.value, font: Font.regular(14.0), textColor: badgeForegroundColor)
        }
        self.badgeTextNode.isAccessibilityElement = false
        self.badgeTextNode.isUserInteractionEnabled = false
        self.badgeTextNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = action.text
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.statusNode.flatMap(self.addSubnode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.badgeBackgroundNode)
        self.addSubnode(self.badgeTextNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highligted in
            guard let strongSelf = self else {
                return
            }
            if highligted {
                strongSelf.highlightedBackgroundNode.alpha = 1.0
            } else {
                strongSelf.highlightedBackgroundNode.alpha = 0.0
                strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.isUserInteractionEnabled = self.action.action != nil
        
        if let iconSource = action.iconSource {
            self.iconDisposable = (iconSource.signal
            |> deliverOnMainQueue).start(next: { [weak self] image in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.iconNode.image = image
            })
        }
    }
    
    deinit {
        self.iconDisposable?.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.pointerInteraction = PointerInteraction(node: self.buttonNode, style: .hover, willEnter: { [weak self] in
            if let strongSelf = self {
                strongSelf.highlightedBackgroundNode.alpha = 0.75
            }
        }, willExit: { [weak self] in
            if let strongSelf = self {
                strongSelf.highlightedBackgroundNode.alpha = 0.0
            }
        })
    }
    
    public func updateLayout(constrainedWidth: CGFloat, previous: ContextActionSibling, next: ContextActionSibling) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let iconSideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 12.0
        
        let iconSize: CGSize
        if let iconSource = self.action.iconSource {
            iconSize = iconSource.size
        } else {
            iconSize = self.iconNode.image.flatMap({ $0.size }) ?? CGSize()
        }
        
        let standardIconWidth: CGFloat = 32.0
        var rightTextInset: CGFloat = sideInset
        if !iconSize.width.isZero {
            rightTextInset = max(iconSize.width, standardIconWidth) + iconSideInset + sideInset
        }
        
        let badgeTextSize = self.badgeTextNode.updateLayout(CGSize(width: constrainedWidth, height: .greatestFiniteMagnitude))
        let badgeInset: CGFloat = 4.0
        
        let badgeSize: CGSize
        let badgeWidthSpace: CGFloat
        let badgeSpacing: CGFloat = 10.0
        if badgeTextSize.width.isZero {
            badgeSize = CGSize()
            badgeWidthSpace = 0.0
        } else {
            badgeSize = CGSize(width: max(18.0, badgeTextSize.width + badgeInset * 2.0), height: 18.0)
            badgeWidthSpace = badgeSize.width + badgeSpacing
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset - badgeWidthSpace, height: .greatestFiniteMagnitude))
        let statusSize = self.statusNode?.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset - badgeWidthSpace, height: .greatestFiniteMagnitude)) ?? CGSize()
        
        if !statusSize.width.isZero, let statusNode = self.statusNode {
            let verticalSpacing: CGFloat = 2.0
            let combinedTextHeight = textSize.height + verticalSpacing + statusSize.height
            return (CGSize(width: max(textSize.width, statusSize.width) + sideInset + rightTextInset + badgeWidthSpace, height: verticalInset * 2.0 + combinedTextHeight), { size, transition in
                let verticalOrigin = floor((size.height - combinedTextHeight) / 2.0)
                let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
                transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
                transition.updateFrameAdditive(node: statusNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin + verticalSpacing + textSize.height), size: statusSize))
                
                let badgeFrame = CGRect(origin: CGPoint(x: textFrame.maxX + badgeSpacing, y: floor((size.height - badgeSize.height) / 2.0)), size: badgeSize)
                transition.updateFrame(node: self.badgeBackgroundNode, frame: badgeFrame)
                transition.updateFrame(node: self.badgeTextNode, frame: CGRect(origin: CGPoint(x: badgeFrame.minX + floorToScreenPixels((badgeFrame.width - badgeTextSize.width) / 2.0), y: badgeFrame.minY + floor((badgeFrame.height - badgeTextSize.height) / 2.0)), size: badgeTextSize))
                
                if !iconSize.width.isZero {
                    transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
                }
                
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            })
        } else {
            return (CGSize(width: textSize.width + sideInset + rightTextInset + badgeWidthSpace, height: verticalInset * 2.0 + textSize.height), { size, transition in
                let verticalOrigin = floor((size.height - textSize.height) / 2.0)
                let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
                transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
                
                if !iconSize.width.isZero {
                    transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
                }
                
                let badgeFrame = CGRect(origin: CGPoint(x: textFrame.maxX + badgeSpacing, y: floor((size.height - badgeSize.height) / 2.0)), size: badgeSize)
                transition.updateFrame(node: self.badgeBackgroundNode, frame: badgeFrame)
                transition.updateFrame(node: self.badgeTextNode, frame: CGRect(origin: CGPoint(x: badgeFrame.minX + floorToScreenPixels((badgeFrame.width - badgeTextSize.width) / 2.0), y: badgeFrame.minY + floor((badgeFrame.height - badgeTextSize.height) / 2.0)), size: badgeTextSize))
                
                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
                transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            })
        }
    }
    
    public func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData

        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        
        let textColor: UIColor
        switch action.textColor {
        case .primary:
            textColor = presentationData.theme.contextMenu.primaryColor
        case .destructive:
            textColor = presentationData.theme.contextMenu.destructiveColor
        case .disabled:
            textColor = presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.4)
        }
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        let smallTextFont = Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0))
        let titleFont: UIFont
        switch self.action.textFont {
        case .regular:
            titleFont = textFont
        case .small:
            titleFont = smallTextFont
        case let .custom(customFont):
            titleFont = customFont
        }
        
        self.textNode.attributedText = NSAttributedString(string: self.action.text, font: titleFont, textColor: textColor)
        
        switch self.action.textLayout {
        case let .secondLineWithValue(value):
            let subtitleFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
            self.statusNode?.attributedText = NSAttributedString(string: value, font: subtitleFont, textColor: presentationData.theme.contextMenu.secondaryColor)
        default:
            break
        }
        
        if self.action.iconSource == nil {
            self.iconNode.image = self.action.icon(presentationData.theme)
        }
        
        self.badgeBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: presentationData.theme.contextMenu.badgeFillColor)
        self.badgeTextNode.attributedText = NSAttributedString(string: self.badgeTextNode.attributedText?.string ?? "", font: Font.regular(14.0), textColor: presentationData.theme.contextMenu.badgeForegroundColor)
    }
    
    @objc private func buttonPressed() {
        self.performAction()
    }

    func updateAction(item: ContextMenuActionItem) {
        self.action = item

        let textColor: UIColor
        switch self.action.textColor {
        case .primary:
            textColor = self.presentationData.theme.contextMenu.primaryColor
        case .destructive:
            textColor = self.presentationData.theme.contextMenu.destructiveColor
        case .disabled:
            textColor = self.presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.4)
        }

        let textFont = Font.regular(self.presentationData.listsFontSize.baseDisplaySize)
        let smallTextFont = Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0))
        let titleFont: UIFont
        switch self.action.textFont {
        case .regular:
            titleFont = textFont
        case .small:
            titleFont = smallTextFont
        case let .custom(customFont):
            titleFont = customFont
        }

        self.textNode.attributedText = NSAttributedString(string: self.action.text, font: titleFont, textColor: textColor)

        if self.action.iconSource == nil {
            self.iconNode.image = self.action.icon(self.presentationData.theme)
        }

        self.requestLayout()
    }
    
    public func performAction() {
        guard let controller = self.getController() else {
            return
        }
        self.action.action?(ContextMenuActionItem.Action(
            controller: controller,
            dismissWithResult: { [weak self] result in
                self?.actionSelected(result)
            },
            updateAction: { [weak self] id, updatedAction in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestUpdateAction(id, updatedAction)
            }
        ))
    }
    
    public func setIsHighlighted(_ value: Bool) {
        if value && self.buttonNode.isUserInteractionEnabled {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            self.highlightedBackgroundNode.alpha = 0.0
        }
    }
    
    public func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        return self
    }
}
