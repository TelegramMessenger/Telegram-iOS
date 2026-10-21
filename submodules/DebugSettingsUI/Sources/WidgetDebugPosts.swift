import Foundation
import UIKit
import TelegramCore
import MessageWidget

private final class WidgetDebugBundleAnchor {}

/// A resource bundle the DEBUG app carries in its framework (TelegramUI's `data`), nil in release builds.
private func widgetDebugBundleRoot(_ name: String) -> URL? {
    let outer = Bundle(for: WidgetDebugBundleAnchor.self)
    return Bundle(path: outer.bundlePath + "/\(name).bundle")?.resourceURL
}

/// widget-sandbox v0.1.0's conformance set as its test channel posts it (`channel.json`): each widget with its anchors and
/// caption, then its reference pictures. Empty without `WidgetConformance.bundle`.
func widgetConformanceDebugPosts() -> [EngineLocalWidgetPost] {
    guard let root = widgetDebugBundleRoot("WidgetConformance"), let data = try? Data(contentsOf: root.appendingPathComponent("channel.json")), let posts = try? MessageWidgetChannel.posts(fromJSON: data) else {
        return []
    }
    return posts.compactMap { post in
        guard let html = try? String(contentsOf: root.appendingPathComponent(post.widget), encoding: .utf8) else {
            return nil
        }
        let photos = post.photos.compactMap { path -> EngineLocalWidgetPost.Photo? in
            guard let png = try? Data(contentsOf: root.appendingPathComponent(path)), let image = UIImage(data: png)?.cgImage else {
                return nil
            }
            return EngineLocalWidgetPost.Photo(png: png, width: Int32(image.width), height: Int32(image.height))
        }
        return EngineLocalWidgetPost(html: html, width: post.width, height: post.height, caption: post.caption, photos: photos)
    }
}

/// widget-sandbox v0.1.0's corpus but the attacks, each file a widget with auto anchors and its path as caption. Empty
/// without `WidgetCorpus.bundle`.
func widgetCorpusDebugPosts() -> [EngineLocalWidgetPost] {
    guard let root = widgetDebugBundleRoot("WidgetCorpus") else {
        return []
    }
    return MessageWidgetCorpusListing.items(in: root).map { item in
        return EngineLocalWidgetPost(html: item.source, width: 0, height: 0, caption: item.path, photos: [])
    }
}
