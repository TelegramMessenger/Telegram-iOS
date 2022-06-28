import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle
import ChatPresentationInterfaceState

final class ChatMessageReportInputPanelNode: ChatInputPanelNode {
    private let reportButton: HighlightableButtonNode
    private let separatorNode: ASDisplayNode
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, metrics: LayoutMetrics, isSecondary: Bool)?
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let peerMedia: Bool
        
    var selectedMessages = Set<MessageId>() {
        didSet {
            if oldValue != self.selectedMessages {
                self.reportButton.isEnabled = self.selectedMessages.count != 0
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, peerMedia: Bool = false) {
        self.theme = theme
        self.strings = strings
        self.peerMedia = peerMedia
        
        self.reportButton = HighlightableButtonNode(pointerStyle: .default)
        self.reportButton.isAccessibilityElement = true
        self.reportButton.accessibilityLabel = strings.VoiceOver_MessageContextReport
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
        
        super.init()
        
        self.addSubnode(self.reportButton)
        self.addSubnode(self.separatorNode)
                
        self.reportButton.addTarget(self, action: #selector(self.reportButtonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            
            self.reportButton.setAttributedTitle(NSAttributedString(string: self.reportButton.attributedTitle(for: [])?.string ?? "", font: Font.regular(17.0), textColor: theme.chat.inputPanel.panelControlAccentColor), for: [])
            self.reportButton.setAttributedTitle(NSAttributedString(string: self.reportButton.attributedTitle(for: [])?.string ?? "", font: Font.regular(17.0), textColor: theme.chat.inputPanel.panelControlDisabledColor), for: .disabled)
        }
    }
    
    @objc func reportButtonPressed() {
        self.interfaceInteraction?.reportSelectedMessages()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.reportButton.view
        } else {
            return nil
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
            
            let string = NSAttributedString(string: self.strings.Conversation_ReportMessages, font: Font.regular(17.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
            let updated: Bool
            if let current = self.reportButton.attributedTitle(for: []) {
                updated = !current.isEqual(to: string)
            } else {
                updated = true
            }
            if updated {
                self.reportButton.setAttributedTitle(string, for: [])
                self.reportButton.setAttributedTitle(NSAttributedString(string: self.reportButton.attributedTitle(for: [])?.string ?? "", font: Font.regular(17.0), textColor: self.theme.chat.inputPanel.panelControlDisabledColor), for: .disabled)
            }
            self.reportButton.isEnabled = self.selectedMessages.count != 0
        }
        
        let buttonSize = self.reportButton.measure(CGSize(width: width - leftInset - rightInset - 80.0, height: 100.0))
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        self.reportButton.frame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) / 2.0)), size: buttonSize)
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
