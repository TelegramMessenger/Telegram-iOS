import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos

private let deleteImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionThrash"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: .white)

final class AvatarGalleryItemFooterContentNode: GalleryFooterContentNode {
    private let account: Account
    
    private let deleteButton: UIButton
    private let actionButton: UIButton
    
    var delete: (() -> Void)? {
        didSet {
            self.deleteButton.isHidden = self.delete == nil
        }
    }
    
    var share: ((GalleryControllerInteraction) -> Void)?
    
    init(account: Account) {
        self.account = account
        
        self.deleteButton = UIButton()
        self.deleteButton.isHidden = true
        self.actionButton = UIButton()
        
        self.deleteButton.setImage(deleteImage, for: [.normal])
        self.actionButton.setImage(actionImage, for: [.normal])
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.actionButton)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
    }
    
    deinit {
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        var panelHeight: CGFloat = 44.0 + bottomInset
        panelHeight += contentInset
        
        self.actionButton.frame = CGRect(origin: CGPoint(x: leftInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        self.deleteButton.frame = CGRect(origin: CGPoint(x: width - 44.0 - rightInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        return panelHeight
    }
    
    override func animateIn(fromHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.deleteButton.alpha = 1.0
        self.actionButton.alpha = 1.0
    }
    
    override func animateOut(toHeight: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.deleteButton.alpha = 0.0
        self.actionButton.alpha = 0.0
    }
    
    @objc private func deleteButtonPressed() {
        let presentationData = self.account.telegramApplicationContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        let items: [ActionSheetItem] = [
            ActionSheetButtonItem(title: presentationData.strings.Common_Delete, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                self?.delete?()
            })
        ]
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                                   ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                    })
                                    ])
            ])
        self.controllerInteraction?.presentController(actionSheet, nil)
    }
    
    @objc private func actionButtonPressed() {
        if let controllerInteraction = self.controllerInteraction {
            self.share?(controllerInteraction)
        }
    }
}
