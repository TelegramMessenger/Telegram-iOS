import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ThemeGridSelectionPanelNode: ASDisplayNode {
    private let deleteButton: UIButton
    private let shareButton: UIButton
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, metrics: LayoutMetrics)?
    
    private var theme: PresentationTheme
    
    var selectedIndices = Set<Int>() {
        didSet {
//            if oldValue != self.selectedMessages {
//                self.forwardButton.isEnabled = self.selectedMessages.count != 0
//
//                if self.selectedMessages.isEmpty {
//                    self.actions = nil
//                    if let (width, leftInset, rightInset, maxHeight, metrics) = self.validLayout, let interfaceState = self.presentationInterfaceState {
//                        let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, maxHeight: maxHeight, transition: .immediate, interfaceState: interfaceState, metrics: metrics)
//                    }
//                    self.canDeleteMessagesDisposable.set(nil)
//                } else if let account = self.account {
//                    self.canDeleteMessagesDisposable.set((chatAvailableMessageActions(postbox: account.postbox, accountPeerId: account.peerId, messageIds: self.selectedMessages)
//                        |> deliverOnMainQueue).start(next: { [weak self] actions in
//                            if let strongSelf = self {
//                                strongSelf.actions = actions
//                                if let (width, leftInset, rightInset, maxHeight, metrics) = strongSelf.validLayout, let interfaceState = strongSelf.presentationInterfaceState {
//                                    let _ = strongSelf.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, maxHeight: maxHeight, transition: .immediate, interfaceState: interfaceState, metrics: metrics)
//                                }
//                            }
//                        }))
//                }
//            }
        }
    }
    
    var controllerInteraction: ThemeGridControllerInteraction?
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.deleteButton = UIButton()
        self.deleteButton.isEnabled = true
        self.shareButton = UIButton()
        self.shareButton.isEnabled = true
        
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.shareButton)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.shareButton.addTarget(self, action: #selector(self.shareButtonPressed), for: [.touchUpInside])
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        }
    }
    
    @objc func deleteButtonPressed() {
        self.controllerInteraction?.deleteSelectedWallpapers()
    }
    
    @objc func shareButtonPressed() {
        self.controllerInteraction?.shareSelectedWallpapers()
    }
    
    private func defaultHeight(metrics: LayoutMetrics) -> CGFloat {
        if case .regular = metrics.widthClass, case .regular = metrics.heightClass {
            return 49.0
        } else {
            return 45.0
        }
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, metrics: LayoutMetrics) -> CGFloat {
        self.validLayout = (width, leftInset, rightInset, maxHeight, metrics)
        
        let panelHeight = defaultHeight(metrics: metrics)
//
//        if let actions = self.actions {
//            self.deleteButton.isEnabled = false
//            self.reportButton.isEnabled = false
//            self.forwardButton.isEnabled = actions.options.contains(.forward)
//            self.shareButton.isEnabled = false
//
//            self.deleteButton.isEnabled = !actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty
//            self.shareButton.isEnabled = !actions.options.intersection([.forward]).isEmpty
//            self.reportButton.isEnabled = !actions.options.intersection([.report]).isEmpty
//
//            self.deleteButton.isHidden = !self.deleteButton.isEnabled
//            self.reportButton.isHidden = !self.reportButton.isEnabled
//        } else {
//            self.deleteButton.isEnabled = false
//            self.deleteButton.isHidden = true
//            self.reportButton.isEnabled = false
//            self.reportButton.isHidden = true
//            self.forwardButton.isEnabled = false
//            self.shareButton.isEnabled = false
//        }
        

        self.deleteButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 53.0, height: panelHeight))
        self.shareButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 57.0, y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
        
        
        return panelHeight
    }
}
