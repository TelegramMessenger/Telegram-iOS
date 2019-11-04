import Foundation
import Postbox
import TelegramApi

import SyncCore

func telegramMediaWebpageFromApiWebpage(_ webpage: Api.WebPage, url: String?) -> TelegramMediaWebpage? {
    switch webpage {
        case .webPageNotModified:
            return nil
        case let .webPagePending(id, date):
            return TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), content: .Pending(date, url))
        case let .webPage(_, id, url, displayUrl, hash, type, siteName, title, description, photo, embedUrl, embedType, embedWidth, embedHeight, duration, author, document, documents, cachedPage):
            var embedSize: PixelDimensions?
            if let embedWidth = embedWidth, let embedHeight = embedHeight {
                embedSize = PixelDimensions(width: embedWidth, height: embedHeight)
            }
            var webpageDuration: Int?
            if let duration = duration {
                webpageDuration = Int(duration)
            }
            var image: TelegramMediaImage?
            if let photo = photo {
                image = telegramMediaImageFromApiPhoto(photo)
            }
            var file: TelegramMediaFile?
            if let document = document {
                file = telegramMediaFileFromApiDocument(document)
            }
            var files: [TelegramMediaFile]?
            if let documents = documents {
                files = documents.compactMap(telegramMediaFileFromApiDocument)
            }
            var instantPage: InstantPage?
            if let cachedPage = cachedPage {
                instantPage = InstantPage(apiPage: cachedPage)
            }
            return TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), content: .Loaded(TelegramMediaWebpageLoadedContent(url: url, displayUrl: displayUrl, hash: hash, type: type, websiteName: siteName, title: title, text: description, embedUrl: embedUrl, embedType: embedType, embedSize: embedSize, duration: webpageDuration, author: author, image: image, file: file, files: files, instantPage: instantPage)))
        case .webPageEmpty:
            return nil
    }
}
