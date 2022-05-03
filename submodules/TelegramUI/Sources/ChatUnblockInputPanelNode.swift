import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import ChatPresentationInterfaceState

final class ChatUnblockInputPanelNode: ChatInputPanelNode {
    private let button: HighlightableButtonNode
    private let activityIndicator: UIActivityIndicatorView
    
    private var statusDisposable: Disposable?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
            if self.statusDisposable == nil {
                if let startingBot = self.interfaceInteraction?.statuses?.unblockingPeer {
                    self.statusDisposable = (startingBot |> deliverOnMainQueue).start(next: { [weak self] value in
                        if let strongSelf = self {
                            if value != !strongSelf.activityIndicator.isHidden {
                                if value {
                                    strongSelf.activityIndicator.isHidden = false
                                    strongSelf.activityIndicator.startAnimating()
                                } else {
                                    strongSelf.activityIndicator.isHidden = true
                                    strongSelf.activityIndicator.stopAnimating()
                                }
                            }
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
        
        self.button = HighlightableButtonNode()
        self.activityIndicator = UIActivityIndicatorView(style: .gray)
        self.activityIndicator.isHidden = true
        
        super.init()
        
        self.addSubnode(self.button)
        self.view.addSubview(self.activityIndicator)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: [.touchUpInside])
    }
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            
            self.button.setAttributedTitle(NSAttributedString(string: self.button.attributedTitle(for: [])?.string ?? "", font: Font.regular(17.0), textColor: theme.chat.inputPanel.panelControlAccentColor), for: [])
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.button.view
        } else {
            return nil
        }
    }
    
    @objc func buttonPressed() {
        self.interfaceInteraction?.unblockPeer()
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
            
            
            let string: NSAttributedString
            if let user = interfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
                string = NSAttributedString(string: strings.Bot_Unblock, font: Font.regular(17.0), textColor: theme.chat.inputPanel.panelControlAccentColor)
            } else {
                string = NSAttributedString(string: strings.Conversation_Unblock, font: Font.regular(17.0), textColor: theme.chat.inputPanel.panelControlAccentColor)
            }
            let updated: Bool
            if let current = self.button.attributedTitle(for: []) {
                updated = !current.isEqual(to: string)
            } else {
                updated = true
            }
            if updated {
                self.button.setAttributedTitle(string, for: [])
            }
        }
        
        let buttonSize = self.button.measure(CGSize(width: width - leftInset - rightInset - 80.0, height: 100.0))
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        self.button.frame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) / 2.0)), size: buttonSize)
        
        let indicatorSize = self.activityIndicator.bounds.size
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: width - rightInset - indicatorSize.width - 12.0, y: floor((panelHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
