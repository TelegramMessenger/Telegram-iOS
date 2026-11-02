import Foundation

/// How the test bot sends a post's widget (widget-sandbox v0.2.1, a post's `message`): the kind of message (the server's
/// flags) and the bot's state it starts with.
public struct MessageWidgetChannelMessage: Equatable {
    public var kind: MessageWidgetMessageKind
    public var chatData: String?
    public var publicData: String?

    public init(kind: MessageWidgetMessageKind, chatData: String?, publicData: String?) {
        self.kind = kind
        self.chatData = chatData
        self.publicData = publicData
    }
}

/// One post of widget-sandbox's shared test channel (`conformance/channel.json`, v0.1.0): a widget with its anchors and
/// caption, and the reference pictures posted after it. Paths are under the conformance root. Since v0.2.1 a post may
/// say how the bot sends it (`message`; nil without one, or for a kind this client does not know).
/// Where a post's caption is (widget-sandbox v0.4.0): below the widget, none (`withoutCaption`), or above it
/// (`captionAbove`, layer 233's `invert_media`); with none or above, the client draws its time over the widget.
public enum MessageWidgetCaptionPlacement: Equatable {
    case below
    case none
    case above
}

public struct MessageWidgetChannelPost: Equatable {
    public var widget: String
    public var width: Int32
    public var height: Int32
    public var caption: String
    public var photos: [String]
    public var message: MessageWidgetChannelMessage?
    public var captionPlacement: MessageWidgetCaptionPlacement = .below

    public init(widget: String, width: Int32, height: Int32, caption: String, photos: [String], message: MessageWidgetChannelMessage? = nil) {
        self.widget = widget
        self.width = width
        self.height = height
        self.caption = caption
        self.photos = photos
        self.message = message
    }
}

public enum MessageWidgetChannel {
    public struct Malformed: Error {
    }

    private struct File: Decodable {
        struct Message: Decodable {
            var kind: String
            var chatData: String?
            var publicData: String?

            enum CodingKeys: String, CodingKey {
                case kind
                case chatData = "chat_data"
                case publicData = "public_data"
            }
        }
        struct Post: Decodable {
            var widget: String
            var width: Int32
            var height: Int32
            var caption: String
            var photos: [String]
            var message: Message?
            var withoutCaption: Bool?
            var captionAbove: Bool?
        }
        var posts: [Post]
    }

    /// `channel.json`'s posts, in order; throws when the file is not that shape.
    public static func posts(fromJSON data: Data) throws -> [MessageWidgetChannelPost] {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else {
            throw Malformed()
        }
        return file.posts.map { post in
            let message = post.message.flatMap { message in
                MessageWidgetMessageKind(rawValue: message.kind).map { MessageWidgetChannelMessage(kind: $0, chatData: message.chatData, publicData: message.publicData) }
            }
            var channelPost = MessageWidgetChannelPost(widget: post.widget, width: post.width, height: post.height, caption: post.caption, photos: post.photos, message: message)
            if post.withoutCaption == true {
                channelPost.captionPlacement = .none
            } else if post.captionAbove == true {
                channelPost.captionPlacement = .above
            }
            return channelPost
        }
    }
}
