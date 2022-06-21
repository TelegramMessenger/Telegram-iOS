import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AppBundle

final class ThemeGridSelectionPanelNode: ASDisplayNode {
    private let deleteButton: UIButton
    private let shareButton: UIButton
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, metrics: LayoutMetrics)?
    
    private var theme: PresentationTheme
    
    var selectedIds = Set<ThemeGridControllerEntry.StableId>() {
        didSet {
            if oldValue != self.selectedIds {
                self.deleteButton.isEnabled = !self.selectedIds.isEmpty
                self.shareButton.isEnabled = !self.selectedIds.isEmpty
            }
        }
    }
    
    var controllerInteraction: ThemeGridControllerInteraction?
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.deleteButton = UIButton()
        self.deleteButton.isEnabled = false
        self.shareButton = UIButton()
        self.shareButton.isEnabled = false
        
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.shareButton)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.shareButton.addTarget(self, action: #selector(self.shareButtonPressed), for: [.touchUpInside])
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
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
        self.deleteButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 53.0, height: panelHeight))
        self.shareButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 57.0, y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
        
        return panelHeight
    }
}
