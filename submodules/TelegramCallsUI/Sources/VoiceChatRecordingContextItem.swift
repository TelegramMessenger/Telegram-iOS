import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AppBundle
import ContextUI
import TelegramStringFormatting

func generateStartRecordingIcon(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 18.0, height: 18.0), opaque: false, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        context.setLineWidth(1.0 + UIScreenPixel)
        context.setStrokeColor(color.cgColor)
        context.strokeEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: bounds.insetBy(dx: 5.0, dy: 5.0))
    })
}

final class VoiceChatRecordingContextItem: ContextMenuCustomItem {
    fileprivate let timestamp: Int32
    fileprivate let action: (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void
    
    init(timestamp: Int32, action: @escaping (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void) {
        self.timestamp = timestamp
        self.action = action
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return VoiceChatRecordingContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private let textFont = Font.regular(17.0)

class VoiceChatRecordingIconNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let dotNode: ASImageNode
    
    init(hasBackground: Bool) {
        let iconSize = 16.0 + (1.0 + UIScreenPixel) * 2.0
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateCircleImage(diameter: iconSize, lineWidth: 1.0 + UIScreenPixel, color: UIColor.white, backgroundColor: nil)
        self.backgroundNode.isLayerBacked = true
        
        self.dotNode = ASImageNode()
        self.dotNode.displaysAsynchronously = false
        self.dotNode.displayWithoutProcessing = true
        self.dotNode.image = generateFilledCircleImage(diameter: 8.0, color: UIColor(rgb: 0xff3b30))
        self.dotNode.isLayerBacked = true
        
        super.init()
        
        self.isLayerBacked = true
        
        if hasBackground {
            self.addSubnode(self.backgroundNode)
        }
        self.addSubnode(self.dotNode)
    }
    
    override func didEnterHierarchy() {
        self.setupAnimation()
    }
    
    override func didExitHierarchy() {
        self.dotNode.layer.removeAllAnimations()
    }
    
    private func setupAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [1.0 as NSNumber, 1.0 as NSNumber, 0.55 as NSNumber]
        animation.keyTimes = [0.0 as NSNumber, 0.4546 as NSNumber, 0.9091 as NSNumber, 1 as NSNumber]
        animation.duration = 0.7
        animation.autoreverses = true
        animation.repeatCount = Float.infinity
        self.dotNode.layer.add(animation, forKey: "recording")
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
        let dotSize = CGSize(width: 8.0, height: 8.0)
        self.dotNode.frame = CGRect(origin: CGPoint(x: (self.bounds.width - dotSize.width) / 2.0, y: (self.bounds.height - dotSize.height) / 2.0), size: dotSize)
    }
}

private final class VoiceChatRecordingContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private let item: VoiceChatRecordingContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let statusNode: ImmediateTextNode
    private let iconNode: VoiceChatRecordingIconNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private var timer: SwiftSignalKit.Timer?
    
    private var pointerInteraction: PointerInteraction?

    init(presentationData: PresentationData, item: VoiceChatRecordingContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        let subtextFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
        
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
        self.textNode.attributedText = NSAttributedString(string: presentationData.strings.VoiceChat_StopRecording, font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        
        self.textNode.maximumNumberOfLines = 1
        let statusNode = ImmediateTextNode()
        statusNode.isAccessibilityElement = false
        statusNode.isUserInteractionEnabled = false
        statusNode.displaysAsynchronously = false
        statusNode.attributedText = NSAttributedString(string: "0:00", font: subtextFont, textColor: presentationData.theme.contextMenu.secondaryColor)
        statusNode.maximumNumberOfLines = 1
        self.statusNode = statusNode
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = presentationData.strings.VoiceChat_StopRecording
        
        self.iconNode = VoiceChatRecordingIconNode(hasBackground: true)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.iconNode)
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
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    override func didLoad() {
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
        
        let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
            self?.updateTime(transition: .immediate)
        }, queue: Queue.mainQueue())
        self.timer = timer
        timer.start()
    }
    
    private var validLayout: CGSize?
    func updateTime(transition: ContainedViewLayoutTransition) {
        guard let size = self.validLayout else {
            return
        }
        
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        let duration = max(0, timestamp - item.timestamp)
        
        let subtextFont = Font.regular(self.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
        self.statusNode.attributedText = NSAttributedString(string: stringForDuration(Int32(duration)), font: subtextFont, textColor: presentationData.theme.contextMenu.secondaryColor)
        
        let sideInset: CGFloat = 16.0
        let statusSize = self.statusNode.updateLayout(CGSize(width: size.width - sideInset - 32.0, height: .greatestFiniteMagnitude))
        transition.updateFrameAdditive(node: self.statusNode, frame: CGRect(origin: CGPoint(x: sideInset, y: self.statusNode.frame.minY), size: statusSize))
    }
    
    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let iconSideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 12.0
        
        let iconSide = 16.0 + (1.0 + UIScreenPixel) * 2.0
        let iconSize: CGSize = CGSize(width: iconSide, height: iconSide)
        
        let standardIconWidth: CGFloat = 32.0
        var rightTextInset: CGFloat = sideInset
        if !iconSize.width.isZero {
            rightTextInset = max(iconSize.width, standardIconWidth) + iconSideInset + sideInset
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))
        let statusSize = self.statusNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))
        
        let verticalSpacing: CGFloat = 2.0
        let combinedTextHeight = textSize.height + verticalSpacing + statusSize.height
        return (CGSize(width: max(textSize.width, statusSize.width) + sideInset + rightTextInset, height: verticalInset * 2.0 + combinedTextHeight), { size, transition in
            let hadLayout = self.validLayout != nil
            self.validLayout = size
            
            if !hadLayout {
                self.updateTime(transition: .immediate)
            }
            let verticalOrigin = floor((size.height - combinedTextHeight) / 2.0)
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
            transition.updateFrameAdditive(node: self.statusNode, frame: CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin + verticalSpacing + textSize.height), size: textSize))
            
            if !iconSize.width.isZero {
                transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
            }
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        let subtextFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
        
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        self.statusNode.attributedText = NSAttributedString(string: self.statusNode.attributedText?.string ?? "", font: subtextFont, textColor: presentationData.theme.contextMenu.secondaryColor)
    }
    
    @objc private func buttonPressed() {
        self.performAction()
    }
    
    func canBeHighlighted() -> Bool {
        return true
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }
    
    func performAction() {
        guard let controller = self.getController() else {
            return
        }
        self.item.action(controller, { [weak self] result in
            self?.actionSelected(result)
        })
    }
    
    func setIsHighlighted(_ value: Bool) {
        if value {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            self.highlightedBackgroundNode.alpha = 0.0
        }
    }
}
