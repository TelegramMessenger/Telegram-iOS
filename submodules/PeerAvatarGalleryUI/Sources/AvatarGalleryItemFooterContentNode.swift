import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import GalleryUI
import ComponentFlow
import GlassControls

enum AvatarGalleryItemFooterContent {
    case info
    case own(Bool)
}

final class AvatarGalleryItemFooterContentNode: GalleryFooterContentNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var strings: PresentationStrings
    
    private let buttonPanel = ComponentView<Empty>()
    private let mainNode: ASTextNode
    private let setMainButton: HighlightableButtonNode
    
    private var currentTypeText: String?
    private var displayActionButton: Bool = true
    
    private var validLayout: (CGSize, LayoutMetrics, CGFloat, CGFloat, CGFloat, CGFloat)?
    
    var delete: ((UIView) -> Void)? {
        didSet {
            self.requestLayout?(.immediate)
        }
    }
    
    var share: ((GalleryControllerInteraction) -> Void)?
    
    var setMain: (() -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        self.strings = presentationData.strings
        
        self.setMainButton = HighlightableButtonNode()
        self.setMainButton.isHidden = true
        
        self.mainNode = ASTextNode()
        self.mainNode.maximumNumberOfLines = 1
        self.mainNode.isUserInteractionEnabled = false
        self.mainNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.setMainButton)
        self.addSubnode(self.mainNode)
        
        self.setMainButton.addTarget(self, action: #selector(self.setMainButtonPressed), forControlEvents: .touchUpInside)
    }
        
    func setEntry(_ entry: AvatarGalleryEntry, content: AvatarGalleryItemFooterContent) {
        var typeText: String?
        var buttonText: String?
        var canShare = true
        switch entry {
            case let .image(_, _, _, videoRepresentations, peer, _, _, _, _, _, _, _):
                if (!videoRepresentations.isEmpty) {
                    typeText = self.strings.ProfilePhoto_MainVideo
                    buttonText = self.strings.ProfilePhoto_SetMainVideo
                } else {
                    typeText = self.strings.ProfilePhoto_MainPhoto
                    buttonText = self.strings.ProfilePhoto_SetMainPhoto
                }
            
                if let peer = peer {
                    canShare = !peer.isCopyProtectionEnabled
                }
            default:
                break
        }
        
        if self.currentTypeText != typeText {
            self.currentTypeText = typeText
            
            self.mainNode.attributedText = NSAttributedString(string: typeText ?? "", font: Font.regular(17.0), textColor: UIColor(rgb: 0x808080))
            self.setMainButton.setAttributedTitle(NSAttributedString(string: buttonText ?? "", font: Font.regular(17.0), textColor: .white), for: .normal)
            
            if let validLayout = self.validLayout {
                let _ = self.updateLayout(size: validLayout.0, metrics: validLayout.1, leftInset: validLayout.2, rightInset: validLayout.3, bottomInset: validLayout.4, contentInset: validLayout.5, transition: .immediate)
            }
        }
        
        if self.displayActionButton != canShare {
            self.displayActionButton = canShare
            self.requestLayout?(.immediate)
        }
        
        switch content {
            case .info:
                self.mainNode.isHidden = true
                self.setMainButton.isHidden = true
            case let .own(isMainPhoto):
                self.mainNode.isHidden = !isMainPhoto
                self.setMainButton.isHidden = isMainPhoto
        }
    }
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> LayoutInfo {
        self.validLayout = (size, metrics, leftInset, rightInset, bottomInset, contentInset)
        
        let width = size.width
        var panelHeight: CGFloat = 54.0 + bottomInset
        panelHeight += contentInset
        
        var buttonPanelInsets = UIEdgeInsets()
        buttonPanelInsets.left = 8.0
        buttonPanelInsets.right = 8.0
        buttonPanelInsets.bottom = bottomInset + 8.0
        if bottomInset <= 32.0 {
            buttonPanelInsets.left += 18.0
            buttonPanelInsets.right += 18.0
        }
        // Beside a side strip (iPhone Duo) the controls keep to the band between the side insets: in folded
        // landscape-left the strip's status block sits at the bottom, level with them. Equal side insets keep the
        // screen-wide panel.
        let stripInsets: (left: CGFloat, right: CGFloat) = leftInset != rightInset ? (leftInset, rightInset) : (0.0, 0.0)
        buttonPanelInsets.left += stripInsets.left
        buttonPanelInsets.right += stripInsets.right
        let controlsCenterX = stripInsets.left + (width - stripInsets.left - stripInsets.right) / 2.0
        
        let constrainedSize = CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude)
        let controlsY = panelHeight - buttonPanelInsets.bottom - 44.0

        let mainSize = self.mainNode.measure(constrainedSize)
        self.mainNode.frame = CGRect(origin: CGPoint(x: floor(controlsCenterX - mainSize.width / 2.0), y: controlsY + floor((44.0 - mainSize.height) / 2.0)), size: mainSize)

        let mainButtonSize = self.setMainButton.measure(constrainedSize)
        self.setMainButton.frame = CGRect(origin: CGPoint(x: floor(controlsCenterX - mainButtonSize.width / 2.0), y: controlsY + floor((44.0 - mainButtonSize.height) / 2.0)), size: mainButtonSize)

        var leftControlItems: [GlassControlGroupComponent.Item] = []
        var rightControlItems: [GlassControlGroupComponent.Item] = []

        if self.displayActionButton {
            leftControlItems.append(GlassControlGroupComponent.Item(
                id: AnyHashable("forward"),
                content: .icon("Chat/Input/Accessory Panels/MessageSelectionForward"),
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.actionButtonPressed()
                }
            ))
        }

        if self.delete != nil {
            rightControlItems.append(GlassControlGroupComponent.Item(
                id: AnyHashable("delete"),
                content: .icon("Chat/Input/Accessory Panels/MessageSelectionTrash"),
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.deleteButtonPressed()
                }
            ))
        }

        if leftControlItems.isEmpty && rightControlItems.isEmpty {
            self.buttonPanel.view?.removeFromSuperview()
        } else {
            let buttonPanelSize = self.buttonPanel.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(GlassControlPanelComponent(
                    theme: defaultDarkColorPresentationTheme,
                    leftItem: leftControlItems.isEmpty ? nil : GlassControlPanelComponent.Item(
                        items: leftControlItems,
                        background: .panel
                    ),
                    centralItem: nil,
                    rightItem: rightControlItems.isEmpty ? nil : GlassControlPanelComponent.Item(
                        items: rightControlItems,
                        background: .panel
                    ),
                    centerAlignmentIfPossible: true
                )),
                environment: {},
                containerSize: CGSize(width: size.width - buttonPanelInsets.left - buttonPanelInsets.right, height: 44.0)
            )
            let buttonPanelFrame = CGRect(origin: CGPoint(x: buttonPanelInsets.left, y: panelHeight - buttonPanelInsets.bottom - buttonPanelSize.height), size: buttonPanelSize)
            if let buttonPanelView = self.buttonPanel.view {
                if buttonPanelView.superview == nil {
                    self.view.addSubview(buttonPanelView)
                }
                ComponentTransition(transition).setFrame(view: buttonPanelView, frame: buttonPanelFrame)
            }
        }
        
        return LayoutInfo(height: panelHeight, needsShadow: false)
    }
    
    override func animateIn(fromHeight: CGFloat, previousContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition) {
        if let buttonPanelView = self.buttonPanel.view {
            buttonPanelView.alpha = 1.0
        }
        self.mainNode.alpha = 1.0
        self.setMainButton.alpha = 1.0
    }
    
    override func animateOut(toHeight: CGFloat, nextContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        if let buttonPanelView = self.buttonPanel.view {
            buttonPanelView.alpha = 0.0
        }
        self.mainNode.alpha = 0.0
        self.setMainButton.alpha = 0.0
        completion()
    }
    
    @objc private func deleteButtonPressed() {
        let sourceView: UIView
        if let buttonPanelView = self.buttonPanel.view as? GlassControlPanelComponent.View, let itemView = buttonPanelView.rightItemView?.itemView(id: AnyHashable("delete")) {
            sourceView = itemView
        } else if let buttonPanelView = self.buttonPanel.view {
            sourceView = buttonPanelView
        } else {
            sourceView = self.view
        }
        self.delete?(sourceView)
    }
    
    @objc private func actionButtonPressed() {
        if let controllerInteraction = self.controllerInteraction {
            self.share?(controllerInteraction)
        }
    }
    
    @objc private func setMainButtonPressed() {
        self.setMain?()
    }
}
