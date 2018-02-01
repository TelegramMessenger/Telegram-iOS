import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public enum StandaloneUploadMediaError {
    case generic
}

public enum StandaloneUploadMediaEvent {
    case progress(Float)
    case result(Media)
}

public func standaloneUploadedImage(account: Account, peerId: PeerId, text: String, data: Data) -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: .data(data), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false)
        |> mapError { _ -> StandaloneUploadMediaError in return .generic }
        |> mapToSignal { next -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
            switch next {
                case let .inputFile(inputFile):
                    return account.postbox.modify { modifier -> Api.InputPeer? in
                        return modifier.getPeer(peerId).flatMap(apiInputPeer)
                    }
                    |> mapError { _ -> StandaloneUploadMediaError in return .generic }
                    |> mapToSignal { inputPeer -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                        if let inputPeer = inputPeer {
                            return account.network.request(Api.functions.messages.uploadMedia(peer: inputPeer, media: Api.InputMedia.inputMediaUploadedPhoto(flags: 0, file: inputFile, stickers: nil, ttlSeconds: nil)))
                                |> mapError { _ -> StandaloneUploadMediaError in return .generic }
                                |> mapToSignal { media -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                                    switch media {
                                        case let .messageMediaPhoto(_, photo, _):
                                            if let photo = photo {
                                                if let mediaImage = telegramMediaImageFromApiPhoto(photo) {
                                                    return .single(.result(mediaImage))
                                                }
                                            }
                                        default:
                                            break
                                    }
                                    return .fail(.generic)
                                }
                        } else {
                            return .fail(.generic)
                        }
                    }
                case .inputSecretFile:
                    preconditionFailure()
                case let .progress(progress):
                    return .single(.progress(progress))
            }
    }
}

public func standaloneUploadedFile(account: Account, peerId: PeerId, text: String, source: MultipartUploadSource, mimeType: String, attributes: [TelegramMediaFileAttribute]) -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: source, encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: statsCategoryForFileWithAttributes(attributes)), hintFileSize: nil, hintFileIsLarge: false)
        |> mapError { _ -> StandaloneUploadMediaError in return .generic }
        |> mapToSignal { next -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
            switch next {
            case let .inputFile(inputFile):
                return account.postbox.modify { modifier -> Api.InputPeer? in
                    return modifier.getPeer(peerId).flatMap(apiInputPeer)
                    }
                    |> mapError { _ -> StandaloneUploadMediaError in return .generic }
                    |> mapToSignal { inputPeer -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                        if let inputPeer = inputPeer {
                            return account.network.request(Api.functions.messages.uploadMedia(peer: inputPeer, media: Api.InputMedia.inputMediaUploadedDocument(flags: 0, file: inputFile, thumb: nil, mimeType: mimeType, attributes: inputDocumentAttributesFromFileAttributes(attributes), stickers: nil, ttlSeconds: nil)))
                                |> mapError { _ -> StandaloneUploadMediaError in return .generic }
                                |> mapToSignal { media -> Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError> in
                                    switch media {
                                        case let .messageMediaDocument(_, document, _):
                                            if let document = document {
                                                if let mediaFile = telegramMediaFileFromApiDocument(document) {
                                                    return .single(.result(mediaFile))
                                                }
                                            }
                                        default:
                                            break
                                    }
                                    return .fail(.generic)
                            }
                        } else {
                            return .fail(.generic)
                        }
                }
            case .inputSecretFile:
                preconditionFailure()
            case let .progress(progress):
                return .single(.progress(progress))
            }
    }
}
