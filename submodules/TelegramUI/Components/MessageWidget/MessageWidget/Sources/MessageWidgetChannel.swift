import Foundation

/// One post of widget-sandbox's shared test channel (`conformance/channel.json`, v0.1.0): a widget with its anchors and
/// caption, and the reference pictures posted after it. Paths are under the conformance root.
public struct MessageWidgetChannelPost: Equatable {
    public var widget: String
    public var width: Int32
    public var height: Int32
    public var caption: String
    public var photos: [String]

    public init(widget: String, width: Int32, height: Int32, caption: String, photos: [String]) {
        self.widget = widget
        self.width = width
        self.height = height
        self.caption = caption
        self.photos = photos
    }
}

public enum MessageWidgetChannel {
    public struct Malformed: Error {
    }

    private struct File: Decodable {
        struct Post: Decodable {
            var widget: String
            var width: Int32
            var height: Int32
            var caption: String
            var photos: [String]
        }
        var posts: [Post]
    }

    /// `channel.json`'s posts, in order; throws when the file is not that shape.
    public static func posts(fromJSON data: Data) throws -> [MessageWidgetChannelPost] {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else {
            throw Malformed()
        }
        return file.posts.map { MessageWidgetChannelPost(widget: $0.widget, width: $0.width, height: $0.height, caption: $0.caption, photos: $0.photos) }
    }
}
