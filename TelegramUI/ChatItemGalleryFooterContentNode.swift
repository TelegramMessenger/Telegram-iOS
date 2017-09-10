import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos

private let deleteImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionAction"), color: .white)

private let pauseImage = generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    
    let color = UIColor.white
    let diameter: CGFloat = 16.0
    
    context.setFillColor(color.cgColor)
    
    context.translateBy(x: (diameter - size.width) / 2.0, y: (diameter - size.height) / 2.0)
    let _ = try? drawSvgPath(context, path: "M0,1.00087166 C0,0.448105505 0.443716645,0 0.999807492,0 L4.00019251,0 C4.55237094,0 5,0.444630861 5,1.00087166 L5,14.9991283 C5,15.5518945 4.55628335,16 4.00019251,16 L0.999807492,16 C0.447629061,16 0,15.5553691 0,14.9991283 L0,1.00087166 Z M10,1.00087166 C10,0.448105505 10.4437166,0 10.9998075,0 L14.0001925,0 C14.5523709,0 15,0.444630861 15,1.00087166 L15,14.9991283 C15,15.5518945 14.5562834,16 14.0001925,16 L10.9998075,16 C10.4476291,16 10,15.5553691 10,14.9991283 L10,1.00087166 ")
    context.fillPath()
    if (diameter < 40.0) {
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    }
    context.translateBy(x: -(diameter - size.width) / 2.0, y: -(diameter - size.height) / 2.0)
})

private let textFont = Font.regular(16.0)
private let titleFont = Font.medium(15.0)
private let dateFont = Font.regular(14.0)

enum ChatItemGalleryFooterContent {
    case info
    case playbackPause
}

final class ChatItemGalleryFooterContentNode: GalleryFooterContentNode {
    private let account: Account
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let deleteButton: UIButton
    private let actionButton: UIButton
    private let textNode: ASTextNode
    private let authorNameNode: ASTextNode
    private let dateNode: ASTextNode
    private let playbackControlButton: HighlightableButtonNode
    
    private var currentMessageText: String?
    private var currentAuthorNameText: String?
    private var currentDateText: String?
    
    private var currentMessage: Message?
    
    private let messageContextDisposable = MetaDisposable()
    
    var playbackControl: (() -> Void)?
    
    var content: ChatItemGalleryFooterContent = .info {
        didSet {
            if self.content != oldValue {
                switch self.content {
                    case .info:
                        self.authorNameNode.isHidden = false
                        self.dateNode.isHidden = false
                        self.playbackControlButton.isHidden = true
                    case .playbackPause:
                        self.authorNameNode.isHidden = true
                        self.dateNode.isHidden = true
                        self.playbackControlButton.isHidden = false
                }
            }
        }
    }
    
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
        
        self.playbackControlButton = HighlightableButtonNode()
        self.playbackControlButton.setImage(pauseImage, for: [])
        self.playbackControlButton.isHidden = true
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.actionButton)
        self.addSubnode(self.textNode)
        self.addSubnode(self.authorNameNode)
        self.addSubnode(self.dateNode)
        
        self.addSubnode(self.playbackControlButton)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
        
        self.playbackControlButton.addTarget(self, action: #selector(self.playbackControlPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.messageContextDisposable.dispose()
    }
    
    func setup(origin: GalleryItemOriginData?, caption: String) {
        let titleText = origin?.title
        let dateText = origin?.timestamp.flatMap { humanReadableStringForTimestamp(strings: self.strings, timestamp: $0) }
        
        if self.currentMessageText != caption || self.currentAuthorNameText != titleText || self.currentDateText != dateText {
            self.currentMessageText = caption
            
            if caption.isEmpty {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            } else {
                self.textNode.isHidden = false
                self.textNode.attributedText = NSAttributedString(string: caption, font: textFont, textColor: .white)
            }
            
            if let titleText = titleText {
                self.authorNameNode.attributedText = NSAttributedString(string: titleText, font: titleFont, textColor: .white)
            } else {
                self.authorNameNode.attributedText = nil
            }
            if let dateText = dateText {
                self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: .white)
            } else {
                self.dateNode.attributedText = nil
            }
            
            //self.deleteButton.isHidden = !canDelete
            
            self.requestLayout?(.immediate)
        }
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
        
        self.playbackControlButton.frame = CGRect(origin: CGPoint(x: floor((width - 44.0) / 2.0), y: panelHeight - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
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
                            globalTitle = strongSelf.strings.Common_Delete
                        } else if let personalPeerName = personalPeerName {
                            globalTitle = strongSelf.strings.Conversation_DeleteMessagesFor(personalPeerName).0
                        } else {
                            globalTitle = strongSelf.strings.Conversation_DeleteMessagesForEveryone
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
                        items.append(ActionSheetButtonItem(title: strongSelf.strings.Conversation_DeleteMessagesForMe, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: [currentMessage.id], type: .forLocalPeer).start()
                                strongSelf.controllerInteraction?.dismissController()
                            }
                        }))
                    }
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
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
    
    @objc func playbackControlPressed() {
        self.playbackControl?()
    }
}
