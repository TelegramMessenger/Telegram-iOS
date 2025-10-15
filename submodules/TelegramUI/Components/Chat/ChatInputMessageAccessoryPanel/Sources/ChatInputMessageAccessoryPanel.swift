import Foundation
import UIKit
import TelegramPresentationData
import ChatInputAccessoryPanel
import AccountContext
import TelegramCore
import SwiftSignalKit
import ComponentFlow
import Display
import GlassBackgroundComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import TelegramStringFormatting
import PhotoResources
import TextFormat
import CompositeTextNode
import ChatInterfaceState

private func generateCloseIcon() -> UIImage {
    return generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.copy)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 1.0, y: 1.0))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
        context.strokePath()
        context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
        context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
        context.strokePath()
    })!.withRenderingMode(.alwaysTemplate)
}

private func textStringForForwardedMessage(_ message: EngineMessage, strings: PresentationStrings) -> (text: String, entities: [MessageTextEntity], isMedia: Bool) {
    for media in message.media {
        switch media {
        case _ as TelegramMediaImage:
            return (strings.Message_Photo, [], true)
        case let file as TelegramMediaFile:
            if file.isVideoSticker || file.isAnimatedSticker {
                return (strings.Message_Sticker, [], true)
            }
            var fileName: String = strings.Message_File
            for attribute in file.attributes {
                switch attribute {
                case .Sticker:
                    return (strings.Message_Sticker, [], true)
                case let .FileName(name):
                    fileName = name
                case let .Audio(isVoice, _, title, performer, _):
                    if isVoice {
                        return (strings.Message_Audio, [], true)
                    } else {
                        if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                            return (title + " — " + performer, [], true)
                        } else if let title = title, !title.isEmpty {
                            return (title, [], true)
                        } else if let performer = performer, !performer.isEmpty {
                            return (performer, [], true)
                        } else {
                            return (strings.Message_Audio, [], true)
                        }
                    }
                case .Video:
                    if file.isAnimated {
                        return (strings.Message_Animation, [], true)
                    } else {
                        return (strings.Message_Video, [], true)
                    }
                default:
                    break
                }
            }
            return (fileName, [], true)
        case _ as TelegramMediaContact:
            return (strings.Message_Contact, [], true)
        case let game as TelegramMediaGame:
            return (game.title, [], true)
        case _ as TelegramMediaMap:
            return (strings.Message_Location, [], true)
        case _ as TelegramMediaAction:
            return ("", [], true)
        case _ as TelegramMediaPoll:
            return (strings.ForwardedPolls(1), [], true)
        case let todo as TelegramMediaTodo:
            return (todo.text, [], true)
        case let dice as TelegramMediaDice:
            return (dice.emoji, [], true)
        case let invoice as TelegramMediaInvoice:
            return (invoice.title, [], true)
        default:
            break
        }
    }
    return (message.text, message._asMessage().textEntitiesAttribute?.entities ?? [], false)
}

public final class ChatInputMessageAccessoryPanel: Component {
    public typealias EnvironmentType = ChatInputAccessoryPanelEnvironment

    public enum Contents: Equatable {
        public final class Reply: Equatable {
            public let id: EngineMessage.Id
            public let quote: EngineMessageReplyQuote?
            public let todoItemId: Int32?
            public let message: EngineMessage?

            public init(id: EngineMessage.Id, quote: EngineMessageReplyQuote?, todoItemId: Int32?, message: EngineMessage?) {
                self.id = id
                self.quote = quote
                self.todoItemId = todoItemId
                self.message = message
            }

            public static func ==(lhs: Reply, rhs: Reply) -> Bool {
                if lhs.id != rhs.id {
                    return false
                }
                if lhs.quote != rhs.quote {
                    return false
                }
                if lhs.todoItemId != rhs.todoItemId {
                    return false
                }
                if lhs.message?.id != rhs.message?.id {
                    return false
                }
                if lhs.message?.stableVersion != rhs.message?.stableVersion {
                    return false
                }
                return true
            }
        }

        public final class Edit: Equatable {
            public let id: EngineMessage.Id
            public let message: EngineMessage?

            public init(id: EngineMessage.Id, message: EngineMessage?) {
                self.id = id
                self.message = message
            }

            public static func ==(lhs: Edit, rhs: Edit) -> Bool {
                if lhs.id != rhs.id {
                    return false
                }
                if lhs.message?.id != rhs.message?.id {
                    return false
                }
                if lhs.message?.stableVersion != rhs.message?.stableVersion {
                    return false
                }
                return true
            }
        }
        
        public final class Forward: Equatable {
            public let messageIds: [EngineMessage.Id]
            public let forwardOptionsState: ChatInterfaceForwardOptionsState?
            
            public init(messageIds: [EngineMessage.Id], forwardOptionsState: ChatInterfaceForwardOptionsState?) {
                self.messageIds = messageIds
                self.forwardOptionsState = forwardOptionsState
            }
            
            public static func ==(lhs: Forward, rhs: Forward) -> Bool {
                if lhs.messageIds != rhs.messageIds {
                    return false
                }
                if lhs.forwardOptionsState != rhs.forwardOptionsState {
                    return false
                }
                return true
            }
        }
        
        public final class LinkPreview: Equatable {
            public let url: String
            public let webpage: TelegramMediaWebpage
            
            public init(url: String, webpage: TelegramMediaWebpage) {
                self.url = url
                self.webpage = webpage
            }
            
            public static func ==(lhs: LinkPreview, rhs: LinkPreview) -> Bool {
                if lhs.url != rhs.url {
                    return false
                }
                if lhs.webpage != rhs.webpage {
                    return false
                }
                return true
            }
        }
        
        public final class SuggestPost: Equatable {
            public let state: ChatInterfaceState.PostSuggestionState
            
            public init(state: ChatInterfaceState.PostSuggestionState) {
                self.state = state
            }
            
            public static func ==(lhs: SuggestPost, rhs: SuggestPost) -> Bool {
                if lhs.state != rhs.state {
                    return false
                }
                return true
            }
        }

        case reply(Reply)
        case edit(Edit)
        case forward(Forward)
        case linkPreview(LinkPreview)
        case suggestPost(SuggestPost)
    }
    
    let context: AccountContext
    let contents: Contents
    let chatPeerId: EnginePeer.Id?
    let action: ((UIView) -> Void)?
    let dismiss: (UIView) -> Void

    public init(
        context: AccountContext,
        contents: Contents,
        chatPeerId: EnginePeer.Id?,
        action: ((UIView) -> Void)?,
        dismiss: @escaping (UIView) -> Void
    ) {
        self.context = context
        self.contents = contents
        self.chatPeerId = chatPeerId
        self.action = action
        self.dismiss = dismiss
    }

    public static func ==(lhs: ChatInputMessageAccessoryPanel, rhs: ChatInputMessageAccessoryPanel) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.contents != rhs.contents {
            return false
        }
        if lhs.chatPeerId != rhs.chatPeerId {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
    
    public final class View: UIView, ChatInputAccessoryPanelView {
        private let closeButton: HighlightTrackingButton
        private let closeButtonIcon: GlassBackgroundView.ContentImageView
        
        private let lineView: UIImageView
        private let titleNode: CompositeTextNode
        private let text = ComponentView<Empty>()
        private let tintText = ComponentView<Empty>()
        
        public let contentTintView: UIView
        
        private var isUpdating: Bool = false
        private var component: ChatInputMessageAccessoryPanel?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var messages: [EngineMessage] = []
        private var contentDisposable: Disposable?
        
        private var inlineTextStarImage: UIImage?
        private var inlineTextTonImage: (UIImage, UIColor)?
        
        public var transitionData: ChatInputAccessoryPanelTransitionData? {
            guard let textView = self.text.view else {
                return nil
            }
            return ChatInputAccessoryPanelTransitionData(
                titleView: self.titleNode.view,
                textView: textView,
                lineView: self.lineView,
                imageView: nil
            )
        }
        
        public var storedFrameBeforeDismissed: CGRect?
        
        override public init(frame: CGRect) {
            self.contentTintView = UIView()
            
            self.closeButton = HighlightTrackingButton()
            self.closeButtonIcon = GlassBackgroundView.ContentImageView()
            
            self.lineView = UIImageView()
            self.titleNode = CompositeTextNode()
            
            super.init(frame: frame)
            
            self.addSubview(self.lineView)
            self.addSubview(self.titleNode.view)
            
            self.addSubview(self.closeButtonIcon)
            self.contentTintView.addSubview(self.closeButtonIcon.tintMask)
            self.addSubview(self.closeButton)
            
            self.closeButton.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.contentDisposable?.dispose()
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                component.action?(self)
            }
        }
        
        @objc private func closeButtonPressed() {
            guard let component = self.component else {
                return
            }
            component.dismiss(self)
        }
        
        public func update(component: ChatInputMessageAccessoryPanel, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            
            let messageIdsFromComponent: (ChatInputMessageAccessoryPanel) -> [EngineMessage.Id] = { component in
                let messageIds: [EngineMessage.Id]
                switch component.contents {
                case let .edit(edit):
                    messageIds = [edit.id]
                case let .reply(reply):
                    messageIds = [reply.id]
                case let .forward(forward):
                    messageIds = forward.messageIds
                case .linkPreview, .suggestPost:
                    messageIds = []
                }
                return messageIds
            }
            
            let messageIds = messageIdsFromComponent(component)
            if self.component == nil || self.component.flatMap(messageIdsFromComponent) != messageIds {
                self.contentDisposable?.dispose()
                if !messageIds.isEmpty {
                    self.contentDisposable = (component.context.engine.data.subscribe(
                        EngineDataList(messageIds.map { id in
                            return TelegramEngine.EngineData.Item.Messages.Message(id: id)
                        })
                    )
                    |> deliverOnMainQueue).startStrict(next: { [weak self] messages in
                        guard let self else {
                            return
                        }
                        self.messages = messages.compactMap { $0 }
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate, isLocal: true)
                        }
                    })
                }
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if self.closeButtonIcon.image == nil {
                self.closeButtonIcon.image = generateCloseIcon()
            }
            if self.lineView.image == nil {
                self.lineView.image = generateImage(CGSize(width: 2.0, height: 3.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(UIColor.white.cgColor)
                    context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: 1.0).cgPath)
                    context.fillPath()
                })?.withRenderingMode(.alwaysTemplate).stretchableImage(withLeftCapWidth: 0, topCapHeight: 1)
            }
            
            let size = CGSize(width: availableSize.width, height: 52.0)
            
            let containerInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 6.0, right: 0.0)
            
            let lineSize = CGSize(width: 2.0, height: size.height - containerInsets.top - containerInsets.bottom)
            let lineFrame = CGRect(origin: CGPoint(x: containerInsets.left, y: containerInsets.top), size: lineSize)
            transition.setFrame(view: self.lineView, frame: lineFrame)
            self.lineView.tintColor = environment.theme.chat.inputPanel.panelControlAccentColor
            
            let closeButtonSize = CGSize(width: 44.0, height: 44.0)
            let closeButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - closeButtonSize.width, y: floor((size.height - closeButtonSize.height) * 0.5)), size: closeButtonSize)
            transition.setFrame(view: self.closeButton, frame: closeButtonFrame)
            
            if let image = self.closeButtonIcon.image {
                let closeButtonIconFrame = image.size.centered(in: closeButtonFrame)
                transition.setFrame(view: self.closeButtonIcon, frame: closeButtonIconFrame)
            }
            self.closeButtonIcon.tintColor = environment.theme.chat.inputPanel.inputControlColor
            
            let secondaryTextColor = environment.theme.chat.inputPanel.inputPlaceholderColor
            
            var textString: NSAttributedString
            var isPhoto = false
            if self.messages.count == 1, let message = self.messages.first {
                var text = ""
                let effectiveMessage = message
                //TODO:release media
                /*if let currentEditMediaReference = self.currentEditMediaReference {
                 effectiveMessage = effectiveMessage.withUpdatedMedia([currentEditMediaReference.media])
                 }*/
                let (attributedText, _, _) = descriptionStringForMessage(
                    contentSettings: component.context.currentContentSettings.with { $0 },
                    message: effectiveMessage,
                    strings: environment.strings,
                    nameDisplayOrder: environment.nameDisplayOrder,
                    dateTimeFormat: environment.dateTimeFormat,
                    accountPeerId: component.context.account.peerId
                )
                text = attributedText.string
                
                var updatedMediaReference: AnyMediaReference?
                var imageDimensions: CGSize?
                if !message._asMessage().containsSecretMedia {
                    var candidateMediaReference: AnyMediaReference?
                    for media in message.media {
                        if media is TelegramMediaImage || media is TelegramMediaFile {
                            candidateMediaReference = .message(message: MessageReference(message._asMessage()), media: media)
                            break
                        }
                    }
                    
                    if let imageReference = candidateMediaReference?.concrete(TelegramMediaImage.self) {
                        updatedMediaReference = imageReference.abstract
                        if let representation = largestRepresentationForPhoto(imageReference.media) {
                            imageDimensions = representation.dimensions.cgSize
                        }
                    } else if let fileReference = candidateMediaReference?.concrete(TelegramMediaFile.self) {
                        updatedMediaReference = fileReference.abstract
                        if !fileReference.media.isInstantVideo, let representation = largestImageRepresentation(fileReference.media.previewRepresentations), !fileReference.media.isSticker {
                            imageDimensions = representation.dimensions.cgSize
                        }
                    }
                }
                
                /*let imageNodeLayout = self.imageNode.asyncLayout()
                 var applyImage: (() -> Void)?
                 if let imageDimensions = imageDimensions {
                 let boundingSize = CGSize(width: 35.0, height: 35.0)
                 applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: 2.0), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                 }
                 
                 var mediaUpdated = false
                 if let updatedMediaReference = updatedMediaReference, let previousMediaReference = self.previousMediaReference {
                 mediaUpdated = !updatedMediaReference.media.isEqual(to: previousMediaReference.media)
                 } else if (updatedMediaReference != nil) != (self.previousMediaReference != nil) {
                 mediaUpdated = true
                 }
                 self.previousMediaReference = updatedMediaReference*/
                
                let hasSpoiler = message.attributes.contains(where: { $0 is MediaSpoilerMessageAttribute })
                
                var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                let _ = updateImageSignal
                if let updatedMediaReference = updatedMediaReference, imageDimensions != nil {
                    if let imageReference = updatedMediaReference.concrete(TelegramMediaImage.self) {
                        updateImageSignal = chatMessagePhotoThumbnail(account: component.context.account, userLocation: MediaResourceUserLocation.peer(message.id.peerId), photoReference: imageReference, blurred: hasSpoiler)
                        isPhoto = true
                    } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                        if fileReference.media.isVideo {
                            updateImageSignal = chatMessageVideoThumbnail(account: component.context.account, userLocation: MediaResourceUserLocation.peer(message.id.peerId), fileReference: fileReference, blurred: hasSpoiler)
                        } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                            updateImageSignal = chatWebpageSnippetFile(account: component.context.account, userLocation: MediaResourceUserLocation.peer(message.id.peerId), mediaReference: fileReference.abstract, representation: iconImageRepresentation)
                        }
                    }
                } else {
                    updateImageSignal = .single({ _ in return nil })
                }
                
                let isMedia: Bool
                let isText: Bool
                /*if let currentEditMediaReference = self.currentEditMediaReference {
                 effectiveMessage = effectiveMessage.withUpdatedMedia([currentEditMediaReference.media])
                 }*/
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                switch messageContentKind(contentSettings: component.context.currentContentSettings.with { $0 }, message: effectiveMessage, strings: environment.strings, nameDisplayOrder: environment.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat, accountPeerId: component.context.account.peerId) {
                case .text:
                    isMedia = false
                    isText = true
                default:
                    isMedia = effectiveMessage.text.isEmpty
                    isText = false
                }
                
                let textFont = Font.regular(14.0)
                let messageText: NSAttributedString
                if isText {
                    let entities = (message._asMessage().textEntitiesAttribute?.entities ?? []).filter { entity in
                        switch entity.type {
                        case .Spoiler, .CustomEmoji:
                            return true
                        default:
                            return false
                        }
                    }
                    let textColor = environment.theme.chat.inputPanel.primaryTextColor
                    if entities.count > 0 {
                        messageText = stringWithAppliedEntities(trimToLineCount(message.text, lineCount: 1), entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont,  underlineLinks: false, message: message._asMessage())
                    } else {
                        messageText = NSAttributedString(string: text, font: textFont, textColor: isMedia ? secondaryTextColor : environment.theme.chat.inputPanel.primaryTextColor)
                    }
                } else {
                    messageText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: isMedia ? secondaryTextColor : environment.theme.chat.inputPanel.primaryTextColor)
                }
                textString = messageText
            } else {
                textString = NSAttributedString()
            }
            
            var titleText: [CompositeTextNode.Component] = []
            switch component.contents {
            case .edit:
                let canEditMedia: Bool
                //TODO:release
                /*if let message = self.message, !messageMediaEditingOptions(message: message).isEmpty {
                    canEditMedia = true
                } else {
                    canEditMedia = false
                }*/
                canEditMedia = !"".isEmpty
                
                let titleStringValue: String
                if let message = self.messages.first, message.id.namespace == Namespaces.Message.QuickReplyCloud {
                    titleStringValue = environment.strings.Conversation_EditingQuickReplyPanelTitle
                } else if canEditMedia {
                    titleStringValue = isPhoto ? environment.strings.Conversation_EditingPhotoPanelTitle : environment.strings.Conversation_EditingCaptionPanelTitle
                } else {
                    titleStringValue = environment.strings.Conversation_EditingMessagePanelTitle
                }
                titleText = [.text(NSAttributedString(string: titleStringValue, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor))]
            case let .reply(reply):
                if let peer = self.messages.first?.peers[reply.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                    let icon: UIImage?
                    icon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/PanelTextChannelIcon"), color: environment.theme.chat.inputPanel.panelControlAccentColor)
                    
                    if let icon {
                        let rawString: PresentationStrings.FormattedString
                        if reply.quote != nil {
                            rawString = environment.strings.Chat_ReplyPanel_ReplyToQuoteBy(peer.debugDisplayTitle)
                        } else {
                            rawString = environment.strings.Chat_ReplyPanel_ReplyTo(peer.debugDisplayTitle)
                        }
                        if let nameRange = rawString.ranges.first {
                            titleText = []
                            
                            let rawNsString = rawString.string as NSString
                            if nameRange.range.lowerBound != 0 {
                                titleText.append(.text(NSAttributedString(string: rawNsString.substring(with: NSRange(location: 0, length: nameRange.range.lowerBound)), font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor)))
                            }
                            titleText.append(.icon(icon))
                            titleText.append(.text(NSAttributedString(string: peer.debugDisplayTitle, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor)))
                            
                            if nameRange.range.upperBound != rawNsString.length {
                                titleText.append(.text(NSAttributedString(string: rawNsString.substring(with: NSRange(location: nameRange.range.upperBound, length: rawNsString.length - nameRange.range.upperBound)), font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor)))
                            }
                        } else {
                            titleText.append(.text(NSAttributedString(string: rawString.string, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor)))
                        }
                    }
                } else {
                    var authorName = ""
                    if let forwardInfo = self.messages.first?._asMessage().forwardInfo, forwardInfo.flags.contains(.isImported) {
                        if let author = forwardInfo.author {
                            authorName = EnginePeer(author).displayTitle(strings: environment.strings, displayOrder: environment.nameDisplayOrder)
                        } else if let authorSignature = forwardInfo.authorSignature {
                            authorName = authorSignature
                        }
                    } else if let author = self.messages.first?._asMessage().effectiveAuthor {
                        authorName = EnginePeer(author).displayTitle(strings: environment.strings, displayOrder: environment.nameDisplayOrder)
                    }
                    
                    if let _ = reply.todoItemId {
                        let string = environment.strings.Chat_ReplyPanel_ReplyToTodoItem
                        titleText = [.text(NSAttributedString(string: string, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor))]
                    } else if let _ = reply.quote {
                        let string = environment.strings.Chat_ReplyPanel_ReplyToQuoteBy(authorName).string
                        titleText = [.text(NSAttributedString(string: string, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor))]
                    } else {
                        let string = environment.strings.Conversation_ReplyMessagePanelTitle(authorName).string
                        titleText = [.text(NSAttributedString(string: string, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor))]
                    }
                    
                    if reply.id.peerId != component.chatPeerId {
                        if let peer = self.messages.first?.peers[reply.id.peerId], (peer is TelegramChannel || peer is TelegramGroup) {
                            let icon: UIImage?
                            if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                                icon = UIImage(bundleImageName: "Chat/Input/Accessory Panels/PanelTextChannelIcon")
                            } else {
                                icon = UIImage(bundleImageName: "Chat/Input/Accessory Panels/PanelTextGroupIcon")
                            }
                            if let iconImage = generateTintedImage(image: icon, color: environment.theme.chat.inputPanel.panelControlAccentColor) {
                                titleText.append(.icon(iconImage))
                                titleText.append(.text(NSAttributedString(string: peer.debugDisplayTitle, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor)))
                            }
                        }
                    }
                    
                    if let message = self.messages.first {
                        let textFont = Font.regular(14.0)
                        if let quote = reply.quote {
                            let textColor = environment.theme.chat.inputPanel.primaryTextColor
                            textString = stringWithAppliedEntities(trimToLineCount(quote.text, lineCount: 1), entities: quote.entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: message._asMessage())
                        } else if let todoItemId = reply.todoItemId, let todo = message.media.first(where: { $0 is TelegramMediaTodo }) as? TelegramMediaTodo, let todoItem = todo.items.first(where: { $0.id == todoItemId }) {
                            let textColor = environment.theme.chat.inputPanel.primaryTextColor
                            textString = stringWithAppliedEntities(trimToLineCount(todoItem.text, lineCount: 1), entities: todoItem.entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: message._asMessage())
                        }
                    }
                }
            case let .forward(forward):
                var title = ""
                var authors = ""
                var uniquePeerIds = Set<EnginePeer.Id>()
                var text = NSMutableAttributedString(string: "")
                
                for message in self.messages {
                    if let author = message.forwardInfo?.author ?? message._asMessage().effectiveAuthor, !uniquePeerIds.contains(author.id) {
                        uniquePeerIds.insert(author.id)
                        if !authors.isEmpty {
                            authors.append(", ")
                        }
                        if author.id == component.context.account.peerId {
                            authors.append(environment.strings.DialogList_You)
                        } else {
                            authors.append(EnginePeer(author).compactDisplayTitle)
                        }
                    }
                }
                
                if self.messages.count == 1 {
                    title = environment.strings.Conversation_ForwardOptions_ForwardTitleSingle
                    let (string, entities, _) = textStringForForwardedMessage(messages[0], strings: environment.strings)
                    
                    text = NSMutableAttributedString(attributedString: NSAttributedString(string: "\(authors): ", font: Font.regular(14.0), textColor: secondaryTextColor))
                    
                    let additionalText = NSMutableAttributedString(attributedString: NSAttributedString(string: string, font: Font.regular(14.0), textColor: secondaryTextColor))
                    for entity in entities {
                        switch entity.type {
                        case let .CustomEmoji(_, fileId):
                            let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                            if range.lowerBound >= 0 && range.upperBound <= additionalText.length {
                                additionalText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: messages[0].associatedMedia[EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile), range: range)
                            }
                        default:
                            break
                        }
                    }
                    
                    text.append(additionalText)
                } else {
                    title = environment.strings.Conversation_ForwardOptions_ForwardTitle(Int32(messages.count))
                    text = NSMutableAttributedString(attributedString: NSAttributedString(string: environment.strings.Conversation_ForwardFrom(authors).string, font: Font.regular(14.0), textColor: secondaryTextColor))
                }
                
                if forward.forwardOptionsState?.hideNames == true {
                    text = NSMutableAttributedString(attributedString: NSAttributedString(string: environment.strings.Conversation_ForwardOptions_SenderNamesRemoved, font: Font.regular(14.0), textColor: secondaryTextColor))
                }
                
                titleText = [.text(NSAttributedString(string: title, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor))]
                textString = text
            case let .linkPreview(linkPreview):
                var authorName = ""
                var text = ""
                switch linkPreview.webpage.content {
                case .Pending:
                    authorName = environment.strings.Channel_NotificationLoading
                    text = linkPreview.url
                case let .Loaded(content):
                    if let contentText = content.text {
                        text = contentText
                    } else {
                        if let file = content.file, let mediaKind = mediaContentKind(EngineMedia(file)) {
                            if content.type == "telegram_background" {
                                text = environment.strings.Message_Wallpaper
                            } else if content.type == "telegram_theme" {
                                text = environment.strings.Message_Theme
                            } else {
                                text = stringForMediaKind(mediaKind, strings: environment.strings).0.string
                            }
                        } else if content.type == "telegram_theme" {
                            text = environment.strings.Message_Theme
                        } else if content.type == "video" {
                            text = stringForMediaKind(.video, strings: environment.strings).0.string
                        } else if content.type == "telegram_story" {
                            text = stringForMediaKind(.story, strings: environment.strings).0.string
                        } else if let _ = content.image {
                            text = stringForMediaKind(.image, strings: environment.strings).0.string
                        }
                    }
                    
                    if let title = content.title {
                        authorName = title
                    } else if let websiteName = content.websiteName {
                        authorName = websiteName
                    } else {
                        authorName = content.displayUrl
                    }
                }
                
                titleText = [.text(NSAttributedString(string: authorName, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor))]
                textString = NSAttributedString(string: text, font: Font.regular(14.0), textColor: environment.theme.chat.inputPanel.primaryTextColor)
            case let .suggestPost(suggestPost):
                if suggestPost.state.editingOriginalMessageId != nil {
                    titleText.append(.text(NSAttributedString(string: environment.strings.Chat_PostSuggestion_Suggest_InputEditTitle, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor)))
                } else {
                    titleText.append(.text(NSAttributedString(string: environment.strings.Chat_PostSuggestion_Suggest_InputTitle, font: Font.medium(14.0), textColor: environment.theme.chat.inputPanel.panelControlAccentColor)))
                }
                
                let textFont = Font.regular(14.0)
                
                if let price = suggestPost.state.price, price.amount != .zero {
                    let currencySymbol: String
                    let amountString: String
                    switch price.currency {
                    case .stars:
                        currencySymbol = "#"
                        amountString = "\(price.amount)"
                    case .ton:
                        currencySymbol = "$"
                        amountString = formatTonAmountText(price.amount.value, dateTimeFormat: environment.dateTimeFormat)
                    }
                    if let timestamp = suggestPost.state.timestamp {
                        let timeString = humanReadableStringForTimestamp(strings: environment.strings, dateTimeFormat: environment.dateTimeFormat, timestamp: timestamp, alwaysShowTime: true, allowYesterday: false, format: HumanReadableStringFormat(
                            dateFormatString: { value in
                                return PresentationStrings.FormattedString(string: environment.strings.SuggestPost_SetTimeFormat_Date(value).string, ranges: [])
                            },
                            tomorrowFormatString: { value in
                                return PresentationStrings.FormattedString(string: environment.strings.SuggestPost_SetTimeFormat_TomorrowAt(value).string, ranges: [])
                            },
                            todayFormatString: { value in
                                return PresentationStrings.FormattedString(string: environment.strings.SuggestPost_SetTimeFormat_TodayAt(value).string, ranges: [])
                            },
                            yesterdayFormatString: { value in
                                return PresentationStrings.FormattedString(string: environment.strings.SuggestPost_SetTimeFormat_TodayAt(value).string, ranges: [])
                            }
                        )).string
                        textString = NSAttributedString(string: "\(currencySymbol)\(amountString)  📅 \(timeString)", font: textFont, textColor: environment.theme.chat.inputPanel.primaryTextColor)
                    } else {
                        textString = NSAttributedString(string: environment.strings.Chat_PostSuggestion_Suggest_InputSubtitleAnytime("\(currencySymbol)\(amountString)").string, font: textFont, textColor: environment.theme.chat.inputPanel.primaryTextColor)
                    }
                } else {
                    textString = NSAttributedString(string: environment.strings.Chat_PostSuggestion_Suggest_InputSubtitleEmpty, font: textFont, textColor: environment.theme.chat.inputPanel.primaryTextColor)
                }
                
                let mutableTextString = NSMutableAttributedString(attributedString: textString)
                for currency in [.stars, .ton] as [CurrencyAmount.Currency] {
                    var inlineTextStarImage: UIImage?
                    if let current = self.inlineTextStarImage {
                        inlineTextStarImage = current
                    } else {
                        if let image = UIImage(bundleImageName: "Premium/Stars/StarSmall") {
                            let starInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                            inlineTextStarImage = generateImage(CGSize(width: starInsets.left + image.size.width + starInsets.right, height: image.size.height), rotatedContext: { size, context in
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                UIGraphicsPushContext(context)
                                defer {
                                    UIGraphicsPopContext()
                                }
                                
                                image.draw(at: CGPoint(x: starInsets.left, y: starInsets.top))
                            })?.withRenderingMode(.alwaysOriginal)
                            self.inlineTextStarImage = inlineTextStarImage
                        }
                    }
                    
                    var inlineTextTonImage: UIImage?
                    if let current = self.inlineTextTonImage, current.1 == environment.theme.list.itemAccentColor {
                        inlineTextTonImage = current.0
                    } else {
                        if let image = UIImage(bundleImageName: "Ads/TonMedium") {
                            let tonInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                            let inlineTextTonImageValue = generateTintedImage(image: generateImage(CGSize(width: tonInsets.left + image.size.width + tonInsets.right, height: image.size.height), rotatedContext: { size, context in
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                UIGraphicsPushContext(context)
                                defer {
                                    UIGraphicsPopContext()
                                }
                                
                                image.draw(at: CGPoint(x: tonInsets.left, y: tonInsets.top))
                            }), color: environment.theme.list.itemAccentColor)!.withRenderingMode(.alwaysOriginal)
                            inlineTextTonImage = inlineTextTonImageValue
                            self.inlineTextTonImage = (inlineTextTonImageValue, environment.theme.list.itemAccentColor)
                        }
                    }
                    
                    let currencySymbol: String
                    let currencyImage: UIImage?
                    switch currency {
                    case .stars:
                        currencySymbol = "#"
                        currencyImage = inlineTextStarImage
                    case .ton:
                        currencySymbol = "$"
                        currencyImage = inlineTextTonImage
                    }
                    
                    if let range = mutableTextString.string.range(of: currencySymbol), let currencyImage {
                        final class RunDelegateData {
                            let ascent: CGFloat
                            let descent: CGFloat
                            let width: CGFloat
                            
                            init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
                                self.ascent = ascent
                                self.descent = descent
                                self.width = width
                            }
                        }
                        
                        let runDelegateData = RunDelegateData(
                            ascent: Font.regular(14.0).ascender,
                            descent: Font.regular(14.0).descender,
                            width: currencyImage.size.width + 2.0
                        )
                        var callbacks = CTRunDelegateCallbacks(
                            version: kCTRunDelegateCurrentVersion,
                            dealloc: { dataRef in
                                Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
                            },
                            getAscent: { dataRef in
                                let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                                return data.takeUnretainedValue().ascent
                            },
                            getDescent: { dataRef in
                                let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                                return data.takeUnretainedValue().descent
                            },
                            getWidth: { dataRef in
                                let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                                return data.takeUnretainedValue().width
                            }
                        )
                        if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(runDelegateData).toOpaque()) {
                            mutableTextString.addAttribute(NSAttributedString.Key(kCTRunDelegateAttributeName as String), value: runDelegate, range: NSRange(range, in: mutableTextString.string))
                        }
                        mutableTextString.addAttribute(.attachment, value: currencyImage, range: NSRange(range, in: mutableTextString.string))
                        mutableTextString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xffffff), range: NSRange(range, in: mutableTextString.string))
                        mutableTextString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: mutableTextString.string))
                    }
                    
                    textString = mutableTextString
                }
            }
            
            let textInsets = UIEdgeInsets(top: 10.0, left: 8.0, bottom: 0.0, right: 44.0)
            
            self.titleNode.components = titleText
            let titleSize = self.titleNode.update(constrainedSize: CGSize(width: availableSize.width - lineFrame.maxX - textInsets.left - textInsets.right, height: 100.0))
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(textString),
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - lineFrame.maxX - textInsets.left - textInsets.right, height: 100.0)
            )
            let tintTextString = NSMutableAttributedString(attributedString: textString)
            tintTextString.addAttribute(.foregroundColor, value: UIColor.black, range: NSRange(location: 0, length: tintTextString.length))
            let _ = self.tintText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(tintTextString),
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - lineFrame.maxX - textInsets.left - textInsets.right, height: 100.0)
            )
            
            let titleTextSpacing: CGFloat = 1.0
            
            let titleFrame = CGRect(origin: CGPoint(x: lineFrame.maxX + textInsets.left, y: textInsets.top), size: titleSize)
            let textFrame = CGRect(origin: CGPoint(x: lineFrame.maxX + textInsets.left, y: titleFrame.maxY + titleTextSpacing), size: textSize)
            
            transition.setFrame(view: self.titleNode.view, frame: titleFrame)
            
            if let textView = self.text.view, let tintTextView = self.tintText.view {
                if textView.superview == nil {
                    textView.layer.anchorPoint = CGPoint()
                    self.addSubview(textView)
                    
                    tintTextView.layer.anchorPoint = CGPoint()
                    self.contentTintView.addSubview(tintTextView)
                }
                transition.setPosition(view: textView, position: textFrame.origin)
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
                
                transition.setPosition(view: tintTextView, position: textFrame.origin)
                tintTextView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
