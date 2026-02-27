import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import ContextUI
import UndoUI

extension PeerInfoScreenNode {
    func openWorkingHoursContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        guard let cachedData = self.data?.cachedData else {
            return
        }
        
        var businessHours: TelegramBusinessHours?
        if let cachedData = cachedData as? CachedUserData {
            businessHours = cachedData.businessHours
        }
        
        guard let businessHours else {
            return
        }
        
        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            UIPasteboard.general.string = businessHoursTextToCopy(businessHours: businessHours, presentationData: self.presentationData, displayLocalTimezone: false)
            
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.MyProfile_ToastHoursCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        
        var items: [ContextMenuItem] = []
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_HoursActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    let businessHoursSetupScreen = self.context.sharedContext.makeBusinessHoursSetupScreen(context: self.context, initialValue: businessHours, completion: { _ in })
                    self.controller?.push(businessHoursSetupScreen)
                }
            })))
        }
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_HoursActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
            c?.dismiss {
                copyAction()
            }
        })))
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_HoursActionRemove, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, _
                in
                guard let self else {
                    return
                }
                
                var subItems: [ContextMenuItem] = []
                let noAction: ((ContextMenuActionItem.Action) -> Void)? = nil
                subItems.append(.action(ContextMenuActionItem(
                    text: self.presentationData.strings.MyProfile_HoursRemoveConfirmation_Title,
                    textLayout: .multiline,
                    textFont: .small,
                    icon: { _ in nil },
                    action: noAction
                )))
                subItems.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_HoursRemoveConfirmation_Action, textColor: .destructive, icon: { _ in nil }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        let _ = self.context.engine.accountData.updateAccountBusinessHours(businessHours: nil).startStandalone()
                    }
                })))
                c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
            })))
        }
        
        let actions = ContextController.Items(content: .list(items))
        
        let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
    
    func openBusinessLocationContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        guard let cachedData = self.data?.cachedData else {
            return
        }
        
        var businessLocation: TelegramBusinessLocation?
        if let cachedData = cachedData as? CachedUserData {
            businessLocation = cachedData.businessLocation
        }
        
        guard let businessLocation else {
            return
        }
        
        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            UIPasteboard.general.string = businessLocation.address
            
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.MyProfile_ToastLocationCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        
        var items: [ContextMenuItem] = []
        
        if businessLocation.coordinates != nil {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationActionOpen, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LocationSmall"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss(completion: {
                    guard let self else {
                        return
                    }
                    self.interaction.openLocation()
                })
            })))
        }
        
        if !businessLocation.address.isEmpty {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                c?.dismiss {
                    copyAction()
                }
            })))
        }
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    let businessLocationSetupScreen = self.context.sharedContext.makeBusinessLocationSetupScreen(context: self.context, initialValue: businessLocation, completion: { _ in })
                    self.controller?.push(businessLocationSetupScreen)
                }
            })))
            
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationActionRemove, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, _ in
                guard let self else {
                    return
                }
                
                var subItems: [ContextMenuItem] = []
                let noAction: ((ContextMenuActionItem.Action) -> Void)? = nil
                subItems.append(.action(ContextMenuActionItem(
                    text: self.presentationData.strings.MyProfile_LocationRemoveConfirmation_Title,
                    textLayout: .multiline,
                    textFont: .small,
                    icon: { _ in nil },
                    action: noAction
                )))
                subItems.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationRemoveConfirmation_Action, textColor: .destructive, icon: { _ in nil }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        let _ = self.context.engine.accountData.updateAccountBusinessLocation(businessLocation: nil).startStandalone()
                    }
                })))
                c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
            })))
        }
        
        let actions = ContextController.Items(content: .list(items))
        
        let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
}
