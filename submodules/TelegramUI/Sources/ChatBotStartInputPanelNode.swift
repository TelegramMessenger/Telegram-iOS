import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import SolidRoundedButtonNode
import TooltipUI

final class ChatBotStartInputPanelNode: ChatInputPanelNode {
    private let button: SolidRoundedButtonNode
    
    private var statusDisposable: Disposable?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
            if let _ = self.interfaceInteraction {
                if self.statusDisposable == nil {
                    if let startingBot = self.interfaceInteraction?.statuses?.startingBot {
                        self.statusDisposable = (startingBot |> deliverOnMainQueue).start(next: { [weak self] value in
                            if let strongSelf = self {
                                strongSelf.inProgress = value
                            }
                        })
                    }
                }
            }
        }
    }
    
    private var inProgress = false {
        didSet {
            if self.inProgress != oldValue {
                if self.inProgress {
                    self.button.transitionToProgress()
                } else {
                    self.button.transitionFromProgress()
                }
            }
        }
    }
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private var tooltipController: TooltipScreen?
    private var tooltipDismissed = false
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.button = SolidRoundedButtonNode(title: self.strings.Bot_Start, theme: SolidRoundedButtonTheme(theme: theme), height: 50.0, cornerRadius: 11.0, gloss: true)
        self.button.progressType = .embedded
        
        super.init()
        
        self.addSubnode(self.button)

        self.button.pressed = { [weak self] in
            self?.buttonPressed()
        }
    }
    
    deinit {
        self.statusDisposable?.dispose()
        self.tooltipController?.dismiss()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            
            self.button.updateTheme(SolidRoundedButtonTheme(theme: theme))
        }
    }
    
    @objc func buttonPressed() {
        guard let _ = self.context, let presentationInterfaceState = self.presentationInterfaceState else {
            return
        }
        
        self.interfaceInteraction?.sendBotStart(presentationInterfaceState.botStartPayload)
        
        if let tooltipController = self.tooltipController {
            self.tooltipDismissed = false
            self.tooltipController = nil
            tooltipController.dismiss()
        }
    }
    
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        super.updateAbsoluteRect(rect, within: containerSize, transition: transition)
        
        let absoluteFrame = self.button.view.convert(self.button.bounds, to: nil)
        let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY - 1.0), size: CGSize())
        
        if let tooltipController = self.tooltipController, self.view.window != nil {
            tooltipController.location = .point(location, .bottom)
        }
    }
    
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
        }
        
        let inset: CGFloat = max(leftInset, 16.0)
        let maximumWidth: CGFloat = min(430.0, width)
        let proceedHeight = self.button.updateLayout(width: maximumWidth - inset * 2.0, transition: transition)
        let buttonSize = CGSize(width: maximumWidth - inset * 2.0, height: proceedHeight)
        
        let panelHeight = defaultHeight(metrics: metrics) + 27.0
        
        self.button.frame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - buttonSize.width) / 2.0), y: 8.0), size: buttonSize)
        
        if !self.tooltipDismissed, let context = self.context {
            let absoluteFrame = self.button.view.convert(self.button.bounds, to: nil)
            let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY - 1.0), size: CGSize())
            
            if let tooltipController = self.tooltipController {
                if self.view.window != nil {
                    tooltipController.location = .point(location, .bottom)
                }
            } else {
                let controller = TooltipScreen(account: context.account, sharedContext: context.sharedContext, text: self.strings.Bot_TapToUse, icon: .downArrows, location: .point(location, .bottom), displayDuration: .infinite, shouldDismissOnTouch: { _ in
                    return .ignore
                })
                controller.alwaysVisible = true
                self.tooltipController = controller
                
                let delay: Double
                if case .regular = metrics.widthClass {
                    delay = 0.1
                } else {
                    delay = 0.35
                }
                Queue.mainQueue().after(delay, {
                    let absoluteFrame = self.button.view.convert(self.button.bounds, to: nil)
                    let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY - 1.0), size: CGSize())
                    controller.location = .point(location, .bottom)
                    self.interfaceInteraction?.presentControllerInCurrent(controller, nil)
                })
            }
        }
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics) + 27.0
    }
}
