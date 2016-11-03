import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

enum PendingMessageUploadedContent {
    case text(String)
    case media(Api.InputMedia)
    case forward(ForwardSourceInfoAttribute)
}

enum PendingMessageUploadedContentResult {
    case progress(Float)
    case content(Message, PendingMessageUploadedContent)
}

func uploadedMessageContent(network: Network, postbox: Postbox, message: Message) -> Signal<PendingMessageUploadedContentResult, NoError> {
    if let forwardInfo = message.forwardInfo {
        var forwardSourceInfo: ForwardSourceInfoAttribute?
        for attribute in message.attributes {
            if let attribute = attribute as? ForwardSourceInfoAttribute {
                forwardSourceInfo = attribute
            }
        }
        if let forwardSourceInfo = forwardSourceInfo {
            return .single(.content(message, .forward(forwardSourceInfo)))
        } else {
            return .never()
        }
    } else if let media = message.media.first {
        if let image = media as? TelegramMediaImage, let largestRepresentation = largestImageRepresentation(image.representations) {
            return uploadedMediaImageContent(network: network, postbox: postbox, image: image, message: message)
        } else if let file = media as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
            return .single(.content(message, .media(Api.InputMedia.inputMediaDocument(id: Api.InputDocument.inputDocument(id: resource.fileId, accessHash: resource.accessHash), caption: message.text))))
        } else {
            return .single(.content(message, .text(message.text)))
        }
    } else {
        return .single(.content(message, .text(message.text)))
    }
}

private func uploadedMediaImageContent(network: Network, postbox: Postbox, image: TelegramMediaImage, message: Message) -> Signal<PendingMessageUploadedContentResult, NoError> {
    if let largestRepresentation = largestImageRepresentation(image.representations) {
        return multipartUpload(network: network, postbox: postbox, resource: largestRepresentation.resource)
            |> map { next -> PendingMessageUploadedContentResult in
                switch next {
                    case let .progress(progress):
                        return .progress(progress)
                    case let .inputFile(file):
                        return .content(message, .media(Api.InputMedia.inputMediaUploadedPhoto(file: file, caption: message.text)))
                }
            }
    } else {
        return .single(.content(message, .text(message.text)))
    }
}
