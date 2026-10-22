import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import ChatPresentationInterfaceState
import ChatInputPanelNode
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters
import MultilineTextComponent

final class DeleteChatInputPanelNode: ChatInputPanelNode {
    private let backgroundView: GlassBackgroundView
    private let title = ComponentView<Empty>()
    private let button: HighlightTrackingButton
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override init() {
        self.backgroundView = GlassBackgroundView()
        self.backgroundView.isUserInteractionEnabled = false
        
        self.button = HighlightTrackingButton()
        
        super.init()
        
        self.view.addSubview(self.button)
        self.view.addSubview(self.backgroundView)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: [.touchUpInside])
        
        self.button.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.backgroundView.contentView.alpha = 0.6
            } else {
                self.backgroundView.contentView.alpha = 1.0
                self.backgroundView.contentView.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.button
        } else {
            return nil
        }
    }
    
    @objc func buttonPressed() {
        self.interfaceInteraction?.deleteChat()
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        self.presentationInterfaceState = interfaceState
        
        self.button.accessibilityLabel = interfaceState.strings.GroupInfo_DeleteAndExit
        
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: interfaceState.strings.GroupInfo_DeleteAndExit, font: Font.regular(17.0), textColor: interfaceState.theme.chat.inputPanel.panelControlDestructiveColor))
            )),
            environment: {},
            containerSize: CGSize(width: width - leftInset - rightInset - 16.0 * 2.0, height: 100.0)
        )
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        let buttonSize = CGSize(width: titleSize.width + 16.0 * 2.0, height: 40.0)
        let buttonFrame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) * 0.5)), size: buttonSize)
        transition.updateFrame(view: self.button, frame: buttonFrame)
        transition.updateFrame(view: self.backgroundView, frame: buttonFrame)
        self.backgroundView.update(size: buttonFrame.size, cornerRadius: buttonFrame.height * 0.5, isDark: interfaceState.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: ComponentTransition(transition))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((buttonFrame.width - titleSize.width) * 0.5), y: floor((buttonFrame.height - titleSize.height) * 0.5)), size: titleSize)
        if let titleView = self.title.view {
            if titleView.superview == nil {
                self.backgroundView.contentView.addSubview(titleView)
            }
            titleView.frame = titleFrame
        }
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
