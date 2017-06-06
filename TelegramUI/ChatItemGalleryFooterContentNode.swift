import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos

private let deleteImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionAction"), color: .white)

private let textFont = Font.regular(16.0)
private let titleFont = Font.medium(15.0)
private let dateFont = Font.regular(14.0)

final class ChatItemGalleryFooterContentNode: GalleryFooterContentNode {
    private let account: Account
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let deleteButton: UIButton
    private let actionButton: UIButton
    private let textNode: ASTextNode
    private let authorNameNode: ASTextNode
    private let dateNode: ASTextNode
    
    private var currentMessageText: String?
    private var currentAuthorNameText: String?
    private var currentDateText: String?
    
    private var currentMessage: Message?
    
    private let messageContextDisposable = MetaDisposable()
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        self.theme = theme
        self.strings = strings
        
        self.deleteButton = UIButton()
        self.actionButton = UIButton()
        
        self.deleteButton.setImage(deleteImage, for: [.normal])
        self.actionButton.setImage(actionImage, for: [.normal])
        
        self.textNode = ASTextNode()
        self.authorNameNode = ASTextNode()
        self.authorNameNode.maximumNumberOfLines = 1
        self.dateNode = ASTextNode()
        self.dateNode.maximumNumberOfLines = 1
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.actionButton)
        self.addSubnode(self.textNode)
        self.addSubnode(self.authorNameNode)
        self.addSubnode(self.dateNode)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
    }
    
    deinit {
        self.messageContextDisposable.dispose()
    }
    
    func setMessage(_ message: Message) {
        self.currentMessage = message
        
        let canDelete: Bool
        if let peer = message.peers[message.id.peerId] {
            if let _ = peer as? TelegramUser {
                canDelete = true
            } else if let _ = peer as? TelegramGroup {
                canDelete = true
            } else if let channel = peer as? TelegramChannel {
                if message.flags.contains(.Incoming) {
                    canDelete = channel.hasAdminRights(.canDeleteMessages)
                } else {
                    canDelete = true
                }
            } else {
                canDelete = false
            }
        } else {
            canDelete = false
        }
        
        var authorNameText: String?
        
        if let author = message.author {
            authorNameText = author.displayTitle
        } else if let peer = message.peers[message.id.peerId] {
            authorNameText = peer.displayTitle
        }
        
        let dateText = humanReadableStringForTimestamp(strings: self.strings, timestamp: message.timestamp)
        
        if self.currentMessageText != message.text || canDelete != !self.deleteButton.isHidden || self.currentAuthorNameText != authorNameText || self.currentDateText != dateText {
            self.currentMessageText = message.text
            
            if message.text.isEmpty {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            } else {
                self.textNode.isHidden = false
                self.textNode.attributedText = NSAttributedString(string: message.text, font: textFont, textColor: .white)
            }
            
            if let authorNameText = authorNameText {
                self.authorNameNode.attributedText = NSAttributedString(string: authorNameText, font: titleFont, textColor: .white)
            } else {
                self.authorNameNode.attributedText = nil
            }
            self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: .white)
            
            self.deleteButton.isHidden = !canDelete
            
            self.requestLayout?(.immediate)
        }
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        var panelHeight: CGFloat = 44.0
        if !self.textNode.isHidden {
            let sideInset: CGFloat = 8.0
            let topInset: CGFloat = 8.0
            let bottomInset: CGFloat = 8.0
            let textSize = self.textNode.measure(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
            panelHeight += textSize.height + topInset + bottomInset
            transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: sideInset, y: topInset), size: textSize))
        }
        
        self.actionButton.frame = CGRect(origin: CGPoint(x: 0.0, y: panelHeight - 44.0), size: CGSize(width: 44.0, height: 44.0))
        self.deleteButton.frame = CGRect(origin: CGPoint(x: width - 44.0, y: panelHeight - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        let authorNameSize = self.authorNameNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let dateSize = self.dateNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        if authorNameSize.height.isZero {
            transition.updateFrame(node: self.dateNode, frame: CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - 44.0 + floor((44.0 - dateSize.height) / 2.0)), size: dateSize))
        } else {
            let labelsSpacing: CGFloat = 0.0
            transition.updateFrame(node: self.authorNameNode, frame: CGRect(origin: CGPoint(x: floor((width - authorNameSize.width) / 2.0), y: panelHeight - 44.0 + floor((44.0 - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0)), size: authorNameSize))
            transition.updateFrame(node: self.dateNode, frame: CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - 44.0 + floor((44.0 - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0) + authorNameSize.height + labelsSpacing), size: dateSize))
        }
        
        return panelHeight
    }
    
    @objc func deleteButtonPressed() {
        if let currentMessage = self.currentMessage {
            self.messageContextDisposable.set((chatDeleteMessagesOptions(account: self.account, messageIds: [currentMessage.id]) |> deliverOnMainQueue).start(next: { [weak self] options in
                if let strongSelf = self, let controllerInteration = strongSelf.controllerInteraction, !options.isEmpty {
                    let actionSheet = ActionSheetController()
                    var items: [ActionSheetItem] = []
                    var personalPeerName: String?
                    var isChannel = false
                    if let user = currentMessage.peers[currentMessage.id.peerId] as? TelegramUser {
                        personalPeerName = user.compactDisplayTitle
                    } else if let channel = currentMessage.peers[currentMessage.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                        isChannel = true
                    }
                    
                    if options.contains(.globally) {
                        let globalTitle: String
                        if isChannel {
                            globalTitle = "Delete"
                        } else if let personalPeerName = personalPeerName {
                            globalTitle = "Delete for me and \(personalPeerName)"
                        } else {
                            globalTitle = "Delete for everyone"
                        }
                        items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: [currentMessage.id], type: .forEveryone).start()
                                strongSelf.controllerInteraction?.dismissController()
                            }
                        }))
                    }
                    if options.contains(.locally) {
                        items.append(ActionSheetButtonItem(title: "Delete for me", color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: [currentMessage.id], type: .forLocalPeer).start()
                                strongSelf.controllerInteraction?.dismissController()
                            }
                        }))
                    }
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controllerInteration.presentController(actionSheet, nil)
                }
            }))
        }
    }
    
    @objc func actionButtonPressed() {
        if let controllerInteraction = self.controllerInteraction, let currentMessage = self.currentMessage {
            var saveToCameraRoll: (() -> Void)?
            var shareAction: (([PeerId]) -> Void)?
            let shareController = ShareController(account: self.account, shareAction: { peerIds in
                shareAction?(peerIds)
            }, defaultAction: ShareControllerAction(title: "Save to Camera Roll", action: {
                saveToCameraRoll?()
            }))
            controllerInteraction.presentController(shareController, nil)
            shareAction = { [weak shareController, weak self] peerIds in
                shareController?.dismiss()
                
                if let strongSelf = self, let currentMessage = strongSelf.currentMessage {
                    for peerId in peerIds {
                        let _ = enqueueMessages(account: strongSelf.account, peerId: peerId, messages: [.forward(source: currentMessage.id)]).start()
                    }
                }
            }
            saveToCameraRoll = { [weak shareController, weak self] in
                shareController?.dismiss()
                
                if let strongSelf = self, let currentMessage = strongSelf.currentMessage {
                    var resource: (MediaResource, Bool)?
                    for media in currentMessage.media {
                        if let image = media as? TelegramMediaImage {
                            if let representation = largestImageRepresentation(image.representations) {
                                resource = (representation.resource, true)
                            }
                            break
                        } else if let file = media as? TelegramMediaFile {
                            if file.isVideo {
                                resource = (file.resource, false)
                            } else if file.mimeType.hasPrefix("image/") {
                                resource = (file.resource, true)
                            }
                            break
                        }
                    }
                    
                    if let (resource, isImage) = resource {
                        strongSelf.messageContextDisposable.set((strongSelf.account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: true)) |> take(1) |> deliverOnMainQueue).start(next: { data in
                            if data.complete {
                                let tempVideoPath = NSTemporaryDirectory() + "\(arc4random64()).mp4"
                                PHPhotoLibrary.shared().performChanges({
                                    if isImage {
                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)), let image = UIImage(data: data) {
                                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                                            //PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: data.path))
                                        }
                                    } else {
                                        if let _ = try? FileManager.default.copyItem(atPath: data.path, toPath: tempVideoPath) {
                                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: tempVideoPath))
                                        }
                                    }
                                }, completionHandler: { _, error in
                                    if let error = error {
                                        print("\(error)")
                                    }
                                    let _ = try? FileManager.default.removeItem(atPath: tempVideoPath)
                                })
                            }
                        }))
                    }
                }
            }
            return
            
            let actionSheet = ActionSheetController()
            var items: [ActionSheetItem] = []
            
            var canSaveToCameraRoll = false
            for media in currentMessage.media {
                if let _ = media as? TelegramMediaImage {
                    canSaveToCameraRoll = true
                    break
                } else if let file = media as? TelegramMediaFile {
                    if file.isVideo {
                        canSaveToCameraRoll = true
                    } else if file.mimeType.hasPrefix("image/") {
                        canSaveToCameraRoll = true
                    }
                    break
                }
            }
            
            if canSaveToCameraRoll {
                items.append(ActionSheetButtonItem(title: "Save to Camera Roll", color: .accent, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if let strongSelf = self, let currentMessage = strongSelf.currentMessage {
                        var resource: (MediaResource, Bool)?
                        for media in currentMessage.media {
                            if let image = media as? TelegramMediaImage {
                                if let representation = largestImageRepresentation(image.representations) {
                                    resource = (representation.resource, true)
                                }
                                break
                            } else if let file = media as? TelegramMediaFile {
                                if file.isVideo {
                                    resource = (file.resource, false)
                                } else if file.mimeType.hasPrefix("image/") {
                                    resource = (file.resource, true)
                                }
                                break
                            }
                        }
                        
                        if let (resource, isImage) = resource {
                            strongSelf.messageContextDisposable.set((strongSelf.account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: true)) |> take(1) |> deliverOnMainQueue).start(next: { data in
                                if data.complete {
                                    let tempVideoPath = NSTemporaryDirectory() + "\(arc4random64()).mp4"
                                    PHPhotoLibrary.shared().performChanges({
                                        if isImage {
                                            if let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)), let image = UIImage(data: data) {
                                                PHAssetChangeRequest.creationRequestForAsset(from: image)
                                                //PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: data.path))
                                            }
                                        } else {
                                            if let _ = try? FileManager.default.copyItem(atPath: data.path, toPath: tempVideoPath) {
                                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: tempVideoPath))
                                            }
                                        }
                                    }, completionHandler: { _, error in
                                        if let error = error {
                                            print("\(error)")
                                        }
                                        let _ = try? FileManager.default.removeItem(atPath: tempVideoPath)
                                    })
                                }
                            }))
                        }
                    }
                }))
            }
            
            items.append(ActionSheetButtonItem(title: "Forward", color: .accent, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self, let currentMessage = strongSelf.currentMessage {
                    let forwardMessageIds = [currentMessage.id]
                    
                    let controller = PeerSelectionController(account: strongSelf.account)
                    controller.peerSelected = { [weak controller] peerId in
                        if let strongSelf = self, let strongController = controller {
                            let _ = (strongSelf.account.postbox.modify({ modifier -> Void in
                                modifier.updatePeerChatInterfaceState(peerId, update: { currentState in
                                    if let currentState = currentState as? ChatInterfaceState {
                                        return currentState.withUpdatedForwardMessageIds(forwardMessageIds)
                                    } else {
                                        return ChatInterfaceState().withUpdatedForwardMessageIds(forwardMessageIds)
                                    }
                                })
                            }) |> deliverOnMainQueue).start(completed: {
                                if let strongSelf = self {
                                    let ready = ValuePromise<Bool>()
                                    
                                    strongSelf.messageContextDisposable.set((ready.get() |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                        if let strongController = controller {
                                            strongController.dismiss()
                                            self?.controllerInteraction?.dismissController()
                                        }
                                    }))
                                    
                                    strongSelf.controllerInteraction?.replaceRootController(ChatController(account: strongSelf.account, peerId: peerId), ready)
                                }
                            })
                        }
                    }
                    strongSelf.controllerInteraction?.presentController(controller, nil)
                }
            }))
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            controllerInteraction.presentController(actionSheet, nil)
        }
    }
}
