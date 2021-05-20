import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AppBundle
import ContextUI
import TelegramStringFormatting
import ReplayKit
import AccountContext

final class VoiceChatShareScreenContextItem: ContextMenuCustomItem {
    fileprivate let context: AccountContext
    fileprivate let text: String
    fileprivate let icon: (PresentationTheme) -> UIImage?
    fileprivate let action: (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void
    
    init(context: AccountContext, text: String, icon: @escaping (PresentationTheme) -> UIImage?, action: @escaping (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void) {
        self.context = context
        self.text = text
        self.icon = icon
        self.action = action
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return VoiceChatShareScreenContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private let textFont = Font.regular(17.0)

private final class VoiceChatShareScreenContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private let item: VoiceChatShareScreenContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let iconNode: ASImageNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private var timer: SwiftSignalKit.Timer?
    
    private var pointerInteraction: PointerInteraction?
    
    private var broadcastPickerView: UIView?
    private var applicationStateDisposable: Disposable?

    init(presentationData: PresentationData, item: VoiceChatShareScreenContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        
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
        self.textNode.attributedText = NSAttributedString(string: item.text, font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        
        self.textNode.maximumNumberOfLines = 1
    
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = presentationData.strings.VoiceChat_StopRecording
        
        self.iconNode = ASImageNode()
        self.iconNode.isAccessibilityElement = false
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        self.iconNode.image = item.icon(presentationData.theme)
        
        if #available(iOS 12.0, *) {
            let broadcastPickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 52.0))
            broadcastPickerView.alpha = 0.05
            broadcastPickerView.preferredExtension = "\(item.context.sharedContext.applicationBindings.appBundleId).BroadcastUpload"
            broadcastPickerView.showsMicrophoneButton = false
            self.broadcastPickerView = broadcastPickerView
        }
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.buttonNode)
        
        if let broadcastPickerView = self.broadcastPickerView {
            self.view.addSubview(broadcastPickerView)
        }
        
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
        self.applicationStateDisposable?.dispose()
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
        
        self.applicationStateDisposable = (self.item.context.sharedContext.applicationBindings.applicationIsActive
        |> filter { !$0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.getController()?.dismiss(completion: nil)
        })
    }
    
    private var validLayout: CGSize?
    func updateLayout(constrainedWidth: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let iconSideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 12.0
        
        let iconSize = self.iconNode.image.flatMap({ $0.size }) ?? CGSize()
        
        let standardIconWidth: CGFloat = 32.0
        var rightTextInset: CGFloat = sideInset
        if !iconSize.width.isZero {
            rightTextInset = max(iconSize.width, standardIconWidth) + iconSideInset + sideInset
        }
        
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))

        
        let verticalSpacing: CGFloat = 2.0
        let combinedTextHeight = textSize.height + verticalSpacing
        return (CGSize(width: textSize.width + sideInset + rightTextInset, height: verticalInset * 2.0 + combinedTextHeight), { size, transition in
            let hadLayout = self.validLayout != nil
            self.validLayout = size
            
            let verticalOrigin = floor((size.height - combinedTextHeight) / 2.0)
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)

            if !iconSize.width.isZero {
                transition.updateFrameAdditive(node: self.iconNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
            }
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            
            if let broadcastPickerView = self.broadcastPickerView {
                broadcastPickerView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            }
        })
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        let subtextFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0)
        
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
    }
    
    @objc private func buttonPressed() {
        self.performAction()
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
