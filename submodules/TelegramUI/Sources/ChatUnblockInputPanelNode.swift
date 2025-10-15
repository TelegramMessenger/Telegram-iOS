import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import ChatInputPanelNode
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters
import MultilineTextComponent

final class ChatUnblockInputPanelNode: ChatInputPanelNode {
    private let backgroundView: GlassBackgroundView
    private let title = ComponentView<Empty>()
    private let button: HighlightTrackingButton
    
    private var statusDisposable: Disposable?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
            if self.statusDisposable == nil {
                if let startingBot = self.interfaceInteraction?.statuses?.unblockingPeer {
                    self.statusDisposable = (startingBot |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                        if let strongSelf = self {
                            strongSelf.title.view?.alpha = value ? 0.7 : 1.0
                        }
                    })
                }
            }
        }
    }
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
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
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
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
        self.interfaceInteraction?.unblockPeer()
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
        }
        
        let string: String
        if let user = interfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
            string = strings.Bot_Unblock
        } else {
            string = strings.Conversation_Unblock
        }
        
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: string, font: Font.regular(17.0), textColor: theme.chat.inputPanel.panelControlColor))
            )),
            environment: {},
            containerSize: CGSize(width: width - leftInset - rightInset, height: 100.0)
        )
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        let buttonSize = CGSize(width: titleSize.width + 16.0 * 2.0, height: 40.0)
        let buttonFrame = CGRect(origin: CGPoint(x: floor((width - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) * 0.5)), size: buttonSize)
        transition.updateFrame(view: self.button, frame: buttonFrame)
        transition.updateFrame(view: self.backgroundView, frame: buttonFrame)
        self.backgroundView.update(size: buttonFrame.size, cornerRadius: buttonFrame.height * 0.5, isDark: interfaceState.theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: interfaceState.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)), transition: ComponentTransition(transition))
        
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
