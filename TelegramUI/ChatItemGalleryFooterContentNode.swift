import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos

private let deleteImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionThrash"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: .white)

private let backwardImage = UIImage(bundleImageName: "Media Gallery/BackwardButton")
private let forwardImage = UIImage(bundleImageName: "Media Gallery/ForwardButton")

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

private let playImage = generateImage(CGSize(width: 15.0, height: 18.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    
    let color = UIColor.white
    let diameter: CGFloat = 16.0
    
    context.setFillColor(color.cgColor)
    
    context.translateBy(x: (diameter - size.width) / 2.0 + 1.5, y: (diameter - size.height) / 2.0 + 1.0)
    if (diameter < 40.0) {
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 0.8, y: 0.8)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    }
    let _ = try? drawSvgPath(context, path: "M1.71891969,0.209353049 C0.769586558,-0.350676705 0,0.0908839327 0,1.18800046 L0,16.8564753 C0,17.9569971 0.750549162,18.357187 1.67393713,17.7519379 L14.1073836,9.60224049 C15.0318735,8.99626906 15.0094718,8.04970371 14.062401,7.49100858 L1.71891969,0.209353049 ")
    context.fillPath()
    if (diameter < 40.0) {
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    }
    context.translateBy(x: -(diameter - size.width) / 2.0 - 1.5, y: -(diameter - size.height) / 2.0)
})

private let textFont = Font.regular(16.0)
private let titleFont = Font.medium(15.0)
private let dateFont = Font.regular(14.0)

enum ChatItemGalleryFooterContent {
    case info
    case playback(paused: Bool, seekable: Bool)
}

final class ChatItemGalleryFooterContentNode: GalleryFooterContentNode {
    private let account: Account
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    
    private let deleteButton: UIButton
    private let actionButton: UIButton
    private let textNode: ImmediateTextNode
    private let authorNameNode: ASTextNode
    private let dateNode: ASTextNode
    private let backwardButton: HighlightableButtonNode
    private let forwardButton: HighlightableButtonNode
    private let playbackControlButton: HighlightableButtonNode
    
    private var currentMessageText: String?
    private var currentAuthorNameText: String?
    private var currentDateText: String?
    
    private var currentMessage: Message?
    
    private let messageContextDisposable = MetaDisposable()
    
    var playbackControl: (() -> Void)?
    var seekBackward: (() -> Void)?
    var seekForward: (() -> Void)?
    
    var content: ChatItemGalleryFooterContent = .info {
        didSet {
            //if self.content != oldValue {
                switch self.content {
                    case .info:
                        self.authorNameNode.isHidden = false
                        self.dateNode.isHidden = false
                        self.backwardButton.isHidden = true
                        self.forwardButton.isHidden = true
                        self.playbackControlButton.isHidden = true
                    case let .playback(paused, seekable):
                        self.authorNameNode.isHidden = true
                        self.dateNode.isHidden = true
                        self.backwardButton.isHidden = !seekable
                        self.forwardButton.isHidden = !seekable
                        self.playbackControlButton.isHidden = false
                        self.playbackControlButton.setImage(paused ? playImage : pauseImage, for: [])
                }
            //}
        }
    }
    
    var scrubberView: ChatVideoGalleryItemScrubberView? = nil {
        willSet {
            if let scrubberView = self.scrubberView, scrubberView.superview == self.view {
                scrubberView.removeFromSuperview()
            }
        }
        didSet {
            if let scrubberView = self.scrubberView {
                self.view.addSubview(scrubberView)
            }
        }
    }
    
    init(account: Account, presentationData: PresentationData) {
        self.account = account
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.dateTimeFormat = presentationData.dateTimeFormat
        
        self.deleteButton = UIButton()
        self.actionButton = UIButton()
        
        self.deleteButton.setImage(deleteImage, for: [.normal])
        self.actionButton.setImage(actionImage, for: [.normal])
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 10
        self.textNode.isLayerBacked = true
        self.authorNameNode = ASTextNode()
        self.authorNameNode.maximumNumberOfLines = 1
        self.authorNameNode.isLayerBacked = true
        self.authorNameNode.displaysAsynchronously = false
        self.dateNode = ASTextNode()
        self.dateNode.maximumNumberOfLines = 1
        self.dateNode.isLayerBacked = true
        self.dateNode.displaysAsynchronously = false

        self.backwardButton = HighlightableButtonNode()
        self.backwardButton.isHidden = true
        self.backwardButton.setImage(backwardImage, for: [])
        
        self.forwardButton = HighlightableButtonNode()
        self.forwardButton.isHidden = true
        self.forwardButton.setImage(forwardImage, for: [])
        
        self.playbackControlButton = HighlightableButtonNode()
        self.playbackControlButton.isHidden = true
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.actionButton)
        self.addSubnode(self.textNode)
        self.addSubnode(self.authorNameNode)
        self.addSubnode(self.dateNode)

        self.addSubnode(self.backwardButton)
        self.addSubnode(self.forwardButton)
        self.addSubnode(self.playbackControlButton)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
        
        self.backwardButton.addTarget(self, action: #selector(self.backwardButtonPressed), forControlEvents: .touchUpInside)
        self.forwardButton.addTarget(self, action: #selector(self.forwardButtonPressed), forControlEvents: .touchUpInside)
        self.playbackControlButton.addTarget(self, action: #selector(self.playbackControlPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.messageContextDisposable.dispose()
    }
    
    func setup(origin: GalleryItemOriginData?, caption: String) {
        let titleText = origin?.title
        let dateText = origin?.timestamp.flatMap { humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: $0) }
        
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
        
        self.actionButton.isHidden = message.containsSecretMedia
        
        let canDelete: Bool
        if let peer = message.peers[message.id.peerId] {
            if peer is TelegramUser || peer is TelegramSecretChat {
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
        
        let dateText = humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: message.timestamp)
        
        var messageText = ""
        var hasCaption = false
        for media in message.media {
            if media is TelegramMediaImage {
                hasCaption = true
            } else if let file = media as? TelegramMediaFile {
                hasCaption = file.mimeType.hasPrefix("image/")
            }
        }
        if hasCaption {
            messageText = message.text
        }
        
        if self.currentMessageText != messageText || canDelete != !self.deleteButton.isHidden || self.currentAuthorNameText != authorNameText || self.currentDateText != dateText {
            self.currentMessageText = messageText
            
            if messageText.isEmpty {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            } else {
                self.textNode.isHidden = false
                self.textNode.attributedText = NSAttributedString(string: messageText, font: textFont, textColor: .white)
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
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        var panelHeight: CGFloat = 44.0 + bottomInset
        panelHeight += contentInset
        var textFrame = CGRect()
        if !self.textNode.isHidden {
            let sideInset: CGFloat = 8.0 + leftInset
            let topInset: CGFloat = 8.0
            let textBottomInset: CGFloat = 8.0
            let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
            panelHeight += textSize.height + topInset + textBottomInset
            textFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: textSize)
        }
        
        if let scrubberView = self.scrubberView, scrubberView.superview == self.view {
            let sideInset: CGFloat = 8.0 + leftInset
            let topInset: CGFloat = 8.0
            let bottomInset: CGFloat = 8.0
            panelHeight += 34.0 + topInset + bottomInset
            textFrame.origin.y += 34.0 + topInset + bottomInset
            
            scrubberView.frame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: CGSize(width: width - sideInset * 2.0, height: 34.0))
        }
        
        self.textNode.frame = textFrame
        
        self.actionButton.frame = CGRect(origin: CGPoint(x: leftInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        self.deleteButton.frame = CGRect(origin: CGPoint(x: width - 44.0 - rightInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))

        self.backwardButton.frame = CGRect(origin: CGPoint(x: floor((width - 44.0) / 2.0) - 66.0, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        self.forwardButton.frame = CGRect(origin: CGPoint(x: floor((width - 44.0) / 2.0) + 66.0, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        self.playbackControlButton.frame = CGRect(origin: CGPoint(x: floor((width - 44.0) / 2.0), y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        let authorNameSize = self.authorNameNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude))
        let dateSize = self.dateNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        if authorNameSize.height.isZero {
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height) / 2.0)), size: dateSize)
        } else {
            let labelsSpacing: CGFloat = 0.0
            self.authorNameNode.frame = CGRect(origin: CGPoint(x: floor((width - authorNameSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0)), size: authorNameSize)
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0) + authorNameSize.height + labelsSpacing), size: dateSize)
        }
        
        return panelHeight
    }
    
    override func animateIn(fromHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.animatePositionAdditive(node: self.textNode, offset: CGPoint(x: 0.0, y: self.bounds.size.height - fromHeight))
        self.textNode.alpha = 1.0
        self.dateNode.alpha = 1.0
        self.authorNameNode.alpha = 1.0
        self.deleteButton.alpha = 1.0
        self.actionButton.alpha = 1.0
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
    }
    
    override func animateOut(toHeight: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        transition.updateFrame(node: self.textNode, frame: self.textNode.frame.offsetBy(dx: 0.0, dy: self.bounds.height - toHeight))
        self.textNode.alpha = 0.0
        self.dateNode.alpha = 0.0
        self.authorNameNode.alpha = 0.0
        self.deleteButton.alpha = 0.0
        self.actionButton.alpha = 0.0
        self.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { _ in
            completion()
        })
    }
    
    @objc func deleteButtonPressed() {
        if let currentMessage = self.currentMessage {
            let _ = (self.account.postbox.transaction { transaction -> [Message] in
                return transaction.getMessageGroup(currentMessage.id) ?? []
            } |> deliverOnMainQueue).start(next: { [weak self] messages in
                if let strongSelf = self, !messages.isEmpty {
                    if messages.count == 1 {
                        strongSelf.commitDeleteMessages(messages, ask: true)
                    } else {
                        let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                        var generalMessageContentKind: MessageContentKind?
                        for message in messages {
                            let currentKind = messageContentKind(message, strings: presentationData.strings, accountPeerId: strongSelf.account.peerId)
                            if generalMessageContentKind == nil || generalMessageContentKind == currentKind {
                                generalMessageContentKind = currentKind
                            } else {
                                generalMessageContentKind = nil
                                break
                            }
                        }
                        
                        var singleText = presentationData.strings.Media_ShareItem(1)
                        var multipleText = presentationData.strings.Media_ShareItem(Int32(messages.count))
                    
                        if let generalMessageContentKind = generalMessageContentKind {
                            switch generalMessageContentKind {
                                case .image:
                                    singleText = presentationData.strings.Media_ShareThisPhoto
                                    multipleText = presentationData.strings.Media_SharePhoto(Int32(messages.count))
                                case .video:
                                    singleText = presentationData.strings.Media_ShareThisVideo
                                    multipleText = presentationData.strings.Media_ShareVideo(Int32(messages.count))
                                default:
                                    break
                            }
                        }
                    
                        let deleteAction: ([Message]) -> Void = { messages in
                            if let strongSelf = self {
                                strongSelf.commitDeleteMessages(messages, ask: false)
                            }
                        }
                    
                        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                        let items: [ActionSheetItem] = [
                            ActionSheetButtonItem(title: singleText, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                deleteAction([currentMessage])
                            }),
                            ActionSheetButtonItem(title: multipleText, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                deleteAction(messages)
                            })
                        ]
                    
                        actionSheet.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        strongSelf.controllerInteraction?.presentController(actionSheet, nil)
                    }
                }
            })
        }
    }

    private func commitDeleteMessages(_ messages: [Message], ask: Bool) {
        self.messageContextDisposable.set((chatAvailableMessageActions(postbox: self.account.postbox, accountPeerId: self.account.peerId, messageIds: Set(messages.map { $0.id })) |> deliverOnMainQueue).start(next: { [weak self] actions in
            if let strongSelf = self, let controllerInteration = strongSelf.controllerInteraction, !actions.options.isEmpty {
                let actionSheet = ActionSheetController(presentationTheme: strongSelf.theme)
                var items: [ActionSheetItem] = []
                var personalPeerName: String?
                var isChannel = false
                var peerId: PeerId = messages[0].id.peerId
                if let user = messages[0].peers[messages[0].id.peerId] as? TelegramUser {
                    personalPeerName = user.compactDisplayTitle
                } else if let channel = messages[0].peers[messages[0].id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                    isChannel = true
                }
                
                if actions.options.contains(.deleteGlobally) {
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
                            let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: messages.map { $0.id }, type: .forEveryone).start()
                            strongSelf.controllerInteraction?.dismissController()
                        }
                    }))
                }
                if actions.options.contains(.deleteLocally) {
                    var localOptionText = strongSelf.strings.Conversation_DeleteMessagesForMe
                    if strongSelf.account.peerId == peerId {
                        localOptionText = strongSelf.strings.Conversation_Moderate_Delete
                    }
                    items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let strongSelf = self {
                            let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: messages.map { $0.id }, type: .forLocalPeer).start()
                            strongSelf.controllerInteraction?.dismissController()
                        }
                    }))
                }
                if !ask && items.count == 1 {
                    let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: messages.map { $0.id }, type: .forEveryone).start()
                    strongSelf.controllerInteraction?.dismissController()
                } else {
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controllerInteration.presentController(actionSheet, nil)
                }
            }
        }))
    }
    
    @objc func actionButtonPressed() {
        if let currentMessage = self.currentMessage {
            let _ = (self.account.postbox.transaction { transaction -> [Message] in
                return transaction.getMessageGroup(currentMessage.id) ?? []
            } |> deliverOnMainQueue).start(next: { [weak self] messages in
                if let strongSelf = self, !messages.isEmpty {
                    let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                    var generalMessageContentKind: MessageContentKind?
                    for message in messages {
                        let currentKind = messageContentKind(message, strings: presentationData.strings, accountPeerId: strongSelf.account.peerId)
                        if generalMessageContentKind == nil || generalMessageContentKind == currentKind {
                            generalMessageContentKind = currentKind
                        } else {
                            generalMessageContentKind = nil
                            break
                        }
                    }
                    var preferredAction = ShareControllerPreferredAction.default
                    if let generalMessageContentKind = generalMessageContentKind {
                        switch generalMessageContentKind {
                            case .image, .video:
                                preferredAction = .saveToCameraRoll
                            default:
                                break
                        }
                    }
                    
                    if messages.count == 1 {
                        var subject: ShareControllerSubject = ShareControllerSubject.messages(messages)
                        for m in messages[0].media {
                            if let image = m as? TelegramMediaImage {
                                subject = .image(image.representations)
                            } else if let webpage = m as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                if content.embedType == "iframe" {
                                    let item = OpenInItem.url(url: content.url)
                                    if availableOpenInOptions(applicationContext: strongSelf.account.telegramApplicationContext, item: item).count > 1 {
                                        preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Conversation_FileOpenIn, action: { [weak self] in
                                            if let strongSelf = self {
                                                let openInController = OpenInActionSheetController(postbox: strongSelf.account.postbox, applicationContext: strongSelf.account.telegramApplicationContext, theme: presentationData.theme, strings: presentationData.strings, item: item, additionalAction: nil, openUrl: { [weak self] url in
                                                    if let strongSelf = self, let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                                                        openExternalUrl(account: strongSelf.account, url: url, presentationData: presentationData, applicationContext: applicationContext, navigationController: nil, dismissInput: {})
                                                    }
                                                })
                                                strongSelf.controllerInteraction?.presentController(openInController, nil)
                                            }
                                        }))
                                    } else {
                                        preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Web_OpenExternal, action: { [weak self] in
                                            if let strongSelf = self {
                                                openExternalUrl(account: strongSelf.account, url: content.url, presentationData: presentationData, applicationContext: strongSelf.account.telegramApplicationContext, navigationController: nil, dismissInput: {})
                                            }
                                        }))
                                    }
                                } else {
                                    if let file = content.file {
                                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: file))
                                        preferredAction = .saveToCameraRoll
                                    } else if let image = content.image {
                                        subject = .media(.webPage(webPage: WebpageReference(webpage), media: image))
                                        preferredAction = .saveToCameraRoll
                                    }
                                }
                            } else if let file = m as? TelegramMediaFile {
                                subject = .media(.message(message: MessageReference(messages[0]), media: file))
                                if file.isAnimated {
                                    preferredAction = .custom(action: ShareControllerAction(title: presentationData.strings.Preview_SaveGif, action: { [weak self] in
                                        if let strongSelf = self {
                                            let message = messages[0]
                                            let _ = addSavedGif(postbox: strongSelf.account.postbox, fileReference: .message(message: MessageReference(message), media: file)).start()
                                        }
                                    }))
                                } else if file.mimeType.hasPrefix("image/") || file.mimeType.hasPrefix("video/") {
                                    preferredAction = .saveToCameraRoll
                                }
                            }
                        }
                        let shareController = ShareController(account: strongSelf.account, subject: subject, preferredAction: preferredAction)
                        strongSelf.controllerInteraction?.presentController(shareController, nil)
                    } else {
                        var singleText = presentationData.strings.Media_ShareItem(1)
                        var multipleText = presentationData.strings.Media_ShareItem(Int32(messages.count))
                        
                        if let generalMessageContentKind = generalMessageContentKind {
                            switch generalMessageContentKind {
                                case .image:
                                    singleText = presentationData.strings.Media_ShareThisPhoto
                                    multipleText = presentationData.strings.Media_SharePhoto(Int32(messages.count))
                                case .video:
                                    singleText = presentationData.strings.Media_ShareThisVideo
                                    multipleText = presentationData.strings.Media_ShareVideo(Int32(messages.count))
                                default:
                                    break
                            }
                        }
                        
                        let shareAction: ([Message]) -> Void = { messages in
                            if let strongSelf = self {
                                let shareController = ShareController(account: strongSelf.account, subject: .messages(messages), preferredAction: preferredAction)
                                strongSelf.controllerInteraction?.presentController(shareController, nil)
                            }
                        }
                        
                        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                        let items: [ActionSheetItem] = [
                            ActionSheetButtonItem(title: singleText, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                shareAction([currentMessage])
                            }),
                            ActionSheetButtonItem(title: multipleText, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                shareAction(messages)
                            })
                        ]
                        
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        strongSelf.controllerInteraction?.presentController(actionSheet, nil)
                    }
                }
            })
        }
    }
    
    @objc func playbackControlPressed() {
        self.playbackControl?()
    }
    
    @objc func backwardButtonPressed() {
        self.seekBackward?()
    }
    
    @objc func forwardButtonPressed() {
        self.seekForward?()
    }
}
