import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import TextFormat
import PhotoResources
import AvatarComponent
import EmojiStatusComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import NewsFeedSupport

private enum NewsPostThumbnail {
    case image(TelegramMediaImage)
    case video(TelegramMediaFile)

    var mediaId: EngineMedia.Id? {
        switch self {
        case let .image(image):
            return image.imageId
        case let .video(file):
            return file.fileId
        }
    }
}

/// The first photo or video of the post (an album's first item).
private func newsPostThumbnail(_ messages: [EngineMessage]) -> (EngineMessage, NewsPostThumbnail)? {
    for message in messages {
        for media in message.engineMedia {
            switch media {
            case let .image(image):
                return (message, .image(image))
            case let .file(file):
                if file.isVideo {
                    return (message, .video(file))
                }
            default:
                break
            }
        }
    }
    return nil
}

private func newsPostText(component: NewsFeedPostComponent) -> NSAttributedString {
    let theme = component.theme
    let font = Font.regular(15.0)
    if let message = component.messages.first(where: { !$0.text.isEmpty }) {
        var entities: [MessageTextEntity] = []
        for attribute in message.attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                entities = newsPostPreviewEntities(attribute.entities)
            }
        }
        // One character for one, so the entity ranges stay valid.
        let text = message.text.replacingOccurrences(of: "\n", with: " ")
        return stringWithAppliedEntities(text, entities: entities, baseColor: theme.list.itemPrimaryTextColor, linkColor: theme.list.itemPrimaryTextColor, baseFont: font, linkFont: font, boldFont: Font.semibold(15.0), italicFont: Font.italic(15.0), boldItalicFont: Font.semiboldItalic(15.0), fixedFont: Font.monospace(15.0), blockQuoteFont: font, underlineLinks: false, message: message._asMessage())
    }
    guard let message = component.messages.first else {
        return NSAttributedString()
    }
    // A rich message keeps its text in the attribute, so it arrives here as a preview: text, not a label.
    let (summary, isMediaLabel, _) = descriptionStringForMessage(contentSettings: component.context.currentContentSettings.with { $0 }, message: message, strings: component.strings, nameDisplayOrder: component.nameDisplayOrder, dateTimeFormat: component.dateTimeFormat, accountPeerId: component.context.account.peerId)
    return NSAttributedString(string: summary.string, font: font, textColor: isMediaLabel ? theme.list.itemSecondaryTextColor : theme.list.itemPrimaryTextColor)
}

/// A post row: avatar, channel name, verified badge, compact time, up to three lines of text, and an
/// optional thumbnail on the right. Tapping opens the post.
public final class NewsFeedPostComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let peer: EnginePeer
    /// Ascending ids; an album has several.
    public let messages: [EngineMessage]
    public let timeText: String
    public let action: () -> Void

    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, peer: EnginePeer, messages: [EngineMessage], timeText: String, action: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.peer = peer
        self.messages = messages
        self.timeText = timeText
        self.action = action
    }

    public static func ==(lhs: NewsFeedPostComponent, rhs: NewsFeedPostComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.nameDisplayOrder != rhs.nameDisplayOrder {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.messages != rhs.messages {
            return false
        }
        if lhs.timeText != rhs.timeText {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let credibilityIcon = ComponentView<Empty>()
        private let time = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let thumbnailView = TransformImageView()
        private let separatorLayer = SimpleLayer()

        private var component: NewsFeedPostComponent?
        private var thumbnailMediaId: EngineMedia.Id?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.thumbnailView)
            self.layer.addSublayer(self.separatorLayer)
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        @objc private func tapped() {
            self.component?.action()
        }

        func update(component: NewsFeedPostComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            let theme = component.theme

            let sideInset: CGFloat = 16.0
            let topInset: CGFloat = 9.0
            let bottomInset: CGFloat = 10.0
            let avatarSize: CGFloat = 16.0
            let thumbnailSize: CGFloat = 82.0
            let thumbnailSpacing: CGFloat = 12.0

            let thumbnail = newsPostThumbnail(component.messages)
            let contentWidth = availableSize.width - sideInset * 2.0 - (thumbnail != nil ? (thumbnailSize + thumbnailSpacing) : 0.0)

            let timeSize = self.time.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.timeText, font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor)))),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )

            var credibilitySize = CGSize()
            if component.peer.isVerified {
                credibilitySize = self.credibilityIcon.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: .verified(fillColor: theme.list.itemCheckColors.fillColor, foregroundColor: theme.list.itemCheckColors.foregroundColor, sizeType: .compact),
                        isVisibleForAnimations: false,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 16.0, height: 16.0)
                )
            }

            let titleMaxWidth = contentWidth - avatarSize - 6.0 - (credibilitySize.width > 0.0 ? credibilitySize.width + 4.0 : 0.0) - 6.0 - timeSize.width
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.peer.compactDisplayTitle, font: Font.semibold(15.0), textColor: theme.list.itemPrimaryTextColor)),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, titleMaxWidth), height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: sideInset + avatarSize + 6.0, y: topInset), size: titleSize)

            let avatarFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels(titleFrame.midY - avatarSize * 0.5)), size: CGSize(width: avatarSize, height: avatarSize))
            let _ = self.avatar.update(
                transition: .immediate,
                component: AnyComponent(AvatarComponent(context: component.context, theme: theme, peer: component.peer, size: avatarFrame.size)),
                environment: {},
                containerSize: avatarFrame.size
            )
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                transition.setFrame(view: avatarView, frame: avatarFrame)
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }

            var timeOriginX = titleFrame.maxX + 6.0
            if let credibilityView = self.credibilityIcon.view {
                if credibilitySize.width > 0.0 {
                    if credibilityView.superview == nil {
                        self.addSubview(credibilityView)
                    }
                    credibilityView.isHidden = false
                    transition.setFrame(view: credibilityView, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floor(titleFrame.midY - credibilitySize.height * 0.5)), size: credibilitySize))
                    timeOriginX = titleFrame.maxX + 4.0 + credibilitySize.width + 6.0
                } else {
                    credibilityView.isHidden = true
                }
            }
            if let timeView = self.time.view {
                if timeView.superview == nil {
                    self.addSubview(timeView)
                }
                transition.setFrame(view: timeView, frame: CGRect(origin: CGPoint(x: timeOriginX, y: floorToScreenPixels(titleFrame.midY - timeSize.height * 0.5)), size: timeSize))
            }

            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: theme.list.mediaPlaceholderColor,
                    text: .plain(newsPostText(component: component)),
                    maximumNumberOfLines: 3
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, contentWidth), height: 1000.0)
            )
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: titleFrame.maxY + 4.0), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: textFrame)
            }

            var contentBottom = textFrame.maxY
            if let (message, media) = thumbnail {
                let thumbnailFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - thumbnailSize, y: topInset), size: CGSize(width: thumbnailSize, height: thumbnailSize))
                self.thumbnailView.isHidden = false
                transition.setFrame(view: self.thumbnailView, frame: thumbnailFrame)
                var dimensions = thumbnailFrame.size
                switch media {
                case let .image(image):
                    if let largest = largestImageRepresentation(image.representations) {
                        dimensions = largest.dimensions.cgSize
                    }
                    if self.thumbnailMediaId != media.mediaId {
                        self.thumbnailMediaId = media.mediaId
                        self.thumbnailView.setSignal(mediaGridMessagePhoto(account: component.context.account, userLocation: .peer(message.id.peerId), photoReference: .message(message: MessageReference(message._asMessage()), media: image), fullRepresentationSize: CGSize(width: 188.0, height: 188.0)), attemptSynchronously: false)
                    }
                case let .video(file):
                    if let fileDimensions = file.dimensions {
                        dimensions = fileDimensions.cgSize
                    }
                    if self.thumbnailMediaId != media.mediaId {
                        self.thumbnailMediaId = media.mediaId
                        // Not `mediaGridMessageVideo(postbox:)`: `PostboxImportCheck` rejects `.postbox` access here.
                        self.thumbnailView.setSignal(chatMessageVideoThumbnail(account: component.context.account, userLocation: .peer(message.id.peerId), fileReference: .message(message: MessageReference(message._asMessage()), media: file)), attemptSynchronously: false)
                    }
                }
                let makeLayout = self.thumbnailView.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: 10.0), imageSize: dimensions.aspectFilled(thumbnailFrame.size), boundingSize: thumbnailFrame.size, intrinsicInsets: UIEdgeInsets()))
                apply()
                contentBottom = max(contentBottom, thumbnailFrame.maxY)
            } else {
                self.thumbnailView.isHidden = true
                self.thumbnailMediaId = nil
            }

            let height = contentBottom + bottomInset
            self.separatorLayer.backgroundColor = theme.list.itemPlainSeparatorColor.cgColor
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(x: sideInset, y: height - UIScreenPixel, width: availableSize.width - sideInset * 2.0, height: UIScreenPixel))
            return CGSize(width: availableSize.width, height: height)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
