import Foundation
import UIKit
import MessageWidget

/// One widget post as the test channel posts it: the widget, its anchors and caption, then its reference pictures.
public struct WidgetHarnessPost {
    public struct Photo {
        public var png: Data
        public var width: Int32
        public var height: Int32
    }

    public var path: String
    public var html: String
    public var width: Int32
    public var height: Int32
    public var caption: String
    public var photos: [Photo]
    /// The caption shown above the widget (widget-sandbox v0.4.0's `captionAbove`: layer 233's `invert_media`), so the
    /// bubble draws its time over the widget as with no caption.
    public var captionAbove: Bool = false
}

enum WidgetHarnessPosts {
    /// A resource bundle the app carries (BUILD `resources`), or its own resources for the fixtures.
    private static func root(_ set: WidgetHarnessSet) -> URL? {
        switch set {
        case .conformance:
            return Bundle.main.url(forResource: "WidgetConformance", withExtension: "bundle").flatMap(Bundle.init(url:))?.resourceURL
        case .corpus:
            return Bundle.main.url(forResource: "WidgetCorpus", withExtension: "bundle").flatMap(Bundle.init(url:))?.resourceURL
        case .fixture:
            return Bundle.main.resourceURL?.appendingPathComponent("Fixtures")
        }
    }

    static func load(_ options: WidgetHarnessLaunchOptions) -> [WidgetHarnessPost] {
        guard let root = self.root(options.set) else {
            return []
        }
        var posts: [WidgetHarnessPost] = []
        switch options.set {
        case .conformance:
            guard let data = try? Data(contentsOf: root.appendingPathComponent("channel.json")), let channel = try? MessageWidgetChannel.posts(fromJSON: data) else {
                return []
            }
            for post in channel {
                guard let html = try? String(contentsOf: root.appendingPathComponent(post.widget), encoding: .utf8) else {
                    continue
                }
                let photos = post.photos.compactMap { path -> WidgetHarnessPost.Photo? in
                    guard let png = try? Data(contentsOf: root.appendingPathComponent(path)), let image = UIImage(data: png)?.cgImage else {
                        return nil
                    }
                    return WidgetHarnessPost.Photo(png: png, width: Int32(image.width), height: Int32(image.height))
                }
                // widget-sandbox v0.4.0: a widget the client draws its time over, posted without a caption, then with it above.
                var harnessPost = WidgetHarnessPost(path: post.widget, html: html, width: post.width, height: post.height, caption: post.captionPlacement == .none ? "" : post.caption, photos: photos)
                harnessPost.captionAbove = post.captionPlacement == .above
                posts.append(harnessPost)
            }
        case .corpus:
            for item in MessageWidgetCorpusListing.items(in: root) {
                posts.append(WidgetHarnessPost(path: item.path, html: item.source, width: 0, height: 0, caption: item.path, photos: []))
            }
        case .fixture:
            // The top-level fixtures; one in a folder (`resize/`) only when `posts` names it.
            let listed = ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).filter { $0.hasSuffix(".html") }.sorted()
            let files = listed + (options.posts ?? []).filter { $0.hasPrefix("fixture/") && $0.dropFirst("fixture/".count).contains("/") }.map { String($0.dropFirst("fixture/".count)) }
            for file in files {
                guard let html = try? String(contentsOf: root.appendingPathComponent(file), encoding: .utf8) else {
                    continue
                }
                posts.append(WidgetHarnessPost(path: "fixture/" + file, html: html, width: 0, height: 0, caption: "fixture/" + file, photos: []))
            }
        }
        if let filter = options.postFilter {
            posts = posts.filter { $0.path.contains(filter) }
        }
        if let paths = options.posts {
            let all = posts
            posts = paths.compactMap { path in all.first { $0.path == path } }
        }
        if !options.captions {
            posts = posts.map { post in
                var post = post
                post.caption = ""
                return post
            }
        }
        if let anchors = options.anchors {
            posts = posts.map { post in
                var post = post
                post.width = anchors.width
                post.height = anchors.height
                return post
            }
        }
        return posts
    }
}
