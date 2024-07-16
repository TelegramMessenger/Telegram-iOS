import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import Svg

private var faviconCache: [String: UIImage] = [:]
func fetchFavicon(context: AccountContext, url: String, size: CGSize) -> Signal<UIImage?, NoError> {
    if let icon = faviconCache[url] {
        return .single(icon)
    }
    return context.engine.resources.httpData(url: url)
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Data?, NoError> in
        return .single(nil)
    }
    |> map { data in
        if let data {
            if let image = UIImage(data: data) {
                return image
            } else if url.lowercased().contains(".svg"), let preparedData = prepareSvgImage(data, false), let image = renderPreparedImage(preparedData, size, .clear, UIScreenScale, false) {
                return image
            }
            return nil
        } else {
            return nil
        }
    }
    |> beforeNext { image in
        if let image {
            Queue.mainQueue().async {
                faviconCache[url] = image
            }
        }
    }
}
