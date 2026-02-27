import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import ContextUI
import PhoneNumberFormat
import UndoUI

extension PeerInfoScreenNode {
    func openPhone(value: String, node: ASDisplayNode, gesture: ContextGesture?, progress: Promise<Bool>?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        
        let formattedPhoneNumber = formatPhoneNumber(context: self.context, number: value)
        if gesture == nil, formattedPhoneNumber.hasPrefix("+888") {
            let collectibleInfo = Promise<CollectibleItemInfoScreenInitialData?>()
            collectibleInfo.set(self.context.sharedContext.makeCollectibleItemInfoScreenInitialData(context: self.context, peerId: self.peerId, subject: .phoneNumber(value)))
            
            progress?.set(.single(true))
            let _ = (collectibleInfo.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] initialData in
                progress?.set(.single(false))
                
                guard let self else {
                    return
                }
                if let initialData {
                    self.view.endEditing(true)
                    self.controller?.push(self.context.sharedContext.makeCollectibleItemInfoScreen(context: self.context, initialData: initialData))
                } else {
                    self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: "https://fragment.com/numbers", forceExternal: true, presentationData: self.presentationData, navigationController: nil, dismissInput: {})
                }
            })
            
            return
        }
        
        let _ = (combineLatest(
            getUserPeer(engine: self.context.engine, peerId: self.peerId),
            getUserPeer(engine: self.context.engine, peerId: self.context.account.peerId)
        ) |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, accountPeer in
            guard let strongSelf = self else {
                return
            }
            let presentationData = strongSelf.presentationData
                        
            let telegramCallAction: (Bool) -> Void = { [weak self] isVideo in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestCall(isVideo: isVideo)
            }
            
            let phoneCallAction = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(context: strongSelf.context, number: value).replacingOccurrences(of: " ", with: ""))")
            }
            
            let copyAction = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                UIPasteboard.general.string = formatPhoneNumber(context: strongSelf.context, number: value)
                
                strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_PhoneCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }
            
            var accountIsFromUS = false
            if let accountPeer, case let .user(user) = accountPeer, let phone = user.phone {
                if let (country, _) = lookupCountryIdByNumber(phone, configuration: strongSelf.context.currentCountriesConfiguration.with { $0 }) {
                    if country.id == "US" {
                        accountIsFromUS = true
                    }
                }
            }
            
            var isAnonymousNumber = false
            var items: [ContextMenuItem] = []
            
            if strongSelf.isMyProfile {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.MyProfile_PhoneActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        self.openSettings(section: .phoneNumber)
                    }
                })))
            }
            
            if case let .user(peer) = peer, let peerPhoneNumber = peer.phone, formattedPhoneNumber == formatPhoneNumber(context: strongSelf.context, number: peerPhoneNumber) {
                if !strongSelf.isMyProfile {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_TelegramCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Call"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss {
                            telegramCallAction(false)
                        }
                    })))
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_TelegramVideoCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/VideoCall"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss {
                            telegramCallAction(true)
                        }
                    })))
                }
                if !formattedPhoneNumber.hasPrefix("+888") {
                    if !strongSelf.isMyProfile {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_PhoneCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PhoneCall"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                            c?.dismiss {
                                phoneCallAction()
                            }
                        })))
                    }
                } else {
                    isAnonymousNumber = true
                }
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.MyProfile_PhoneActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c?.dismiss {
                        copyAction()
                    }
                })))
            } else {
                if !formattedPhoneNumber.hasPrefix("+888") {
                    if !strongSelf.isMyProfile {
                        items.append(
                            .action(ContextMenuActionItem(text: presentationData.strings.UserInfo_PhoneCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PhoneCall"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                                c?.dismiss {
                                    phoneCallAction()
                                }
                            }))
                        )
                    }
                } else {
                    isAnonymousNumber = true
                }
                items.append(
                    .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.MyProfile_PhoneActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss {
                            copyAction()
                        }
                    }))
                )
            }
            var actions = ContextController.Items(content: .list(items))
            if isAnonymousNumber && !accountIsFromUS {
                let collectibleInfo = Promise<CollectibleItemInfoScreenInitialData?>()
                collectibleInfo.set(strongSelf.context.sharedContext.makeCollectibleItemInfoScreenInitialData(context: strongSelf.context, peerId: strongSelf.peerId, subject: .phoneNumber(value)))
                
                actions.tip = .animatedEmoji(text: strongSelf.presentationData.strings.UserInfo_AnonymousNumberInfo, arguments: nil, file: nil, action: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    let _ = (collectibleInfo.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] initialData in
                        guard let self else {
                            return
                        }
                        if let initialData {
                            self.view.endEditing(true)
                            self.controller?.push(self.context.sharedContext.makeCollectibleItemInfoScreen(context: self.context, initialData: initialData))
                        } else {
                            self.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: "https://fragment.com/numbers", forceExternal: true, presentationData: self.presentationData, navigationController: nil, dismissInput: {})
                        }
                    })
                })
            }
            let contextController = makeContextController(presentationData: strongSelf.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
            strongSelf.controller?.present(contextController, in: .window(.root))
        })
    }
}
