import Foundation
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore
import TelegramApi

public enum ChatHistoryImport {
    public struct Session {
        fileprivate var peerId: PeerId
        fileprivate var inputPeer: Api.InputPeer
        fileprivate var id: Int64
    }
    
    public enum InitImportError {
        case generic
    }
    
    public static func initSession(account: Account, peerId: PeerId, file: TempBoxFile, mediaCount: Int32) -> Signal<Session, InitImportError> {
        return multipartUpload(network: account.network, postbox: account.postbox, source: .tempFile(file), encrypt: false, tag: nil, hintFileSize: nil, hintFileIsLarge: false)
        |> mapError { _ -> InitImportError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Session, InitImportError> in
            switch result {
            case let .inputFile(inputFile):
                return account.postbox.transaction { transaction -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }
                |> castError(InitImportError.self)
                |> mapToSignal { inputPeer -> Signal<Session, InitImportError> in
                    guard let inputPeer = inputPeer else {
                        return .fail(.generic)
                    }
                    return account.network.request(Api.functions.messages.initHistoryImport(peer: inputPeer, file: inputFile, mediaCount: mediaCount))
                    |> mapError { _ -> InitImportError in
                        return .generic
                    }
                    |> map { result -> Session in
                        switch result {
                        case let .historyImport(id):
                            return Session(peerId: peerId, inputPeer: inputPeer, id: id)
                        }
                    }
                }
            case .progress:
                return .complete()
            case .inputSecretFile:
                return .fail(.generic)
            }
        }
    }
    
    public enum MediaType {
        case photo
        case file
        case video
        case sticker
        case voice
    }
    
    public enum UploadMediaError {
        case generic
    }
    
    public static func uploadMedia(account: Account, session: Session, file: TempBoxFile, fileName: String, type: MediaType) -> Signal<Never, UploadMediaError> {
        return multipartUpload(network: account.network, postbox: account.postbox, source: .tempFile(file), encrypt: false, tag: nil, hintFileSize: nil, hintFileIsLarge: false)
        |> mapError { _ -> UploadMediaError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, UploadMediaError> in
            let inputMedia: Api.InputMedia
            switch result {
            case let .inputFile(inputFile):
                switch type {
                case .photo:
                    inputMedia = .inputMediaUploadedPhoto(flags: 0, file: inputFile, stickers: nil, ttlSeconds: nil)
                case .file, .video, .sticker, .voice:
                    var attributes: [Api.DocumentAttribute] = []
                    attributes.append(.documentAttributeFilename(fileName: fileName))
                    var mimeType = "application/octet-stream"
                    switch type {
                    case .video:
                        mimeType = "video/mp4"
                    case .sticker:
                        mimeType = "image/webp"
                    case .voice:
                        mimeType = "audio/ogg"
                    default:
                        break
                    }
                    inputMedia = .inputMediaUploadedDocument(flags: 0, file: inputFile, thumb: nil, mimeType: mimeType, attributes: attributes, stickers: nil, ttlSeconds: nil)
                }
            case .progress:
                return .complete()
            case .inputSecretFile:
                return .fail(.generic)
            }
            return account.network.request(Api.functions.messages.uploadImportedMedia(peer: session.inputPeer, importId: session.id, fileName: fileName, media: inputMedia))
            |> mapError { _ -> UploadMediaError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Never, UploadMediaError> in
                return .complete()
            }
        }
    }
    
    public enum StartImportError {
        case generic
    }
    
    public static func startImport(account: Account, session: Session) -> Signal<Never, StartImportError> {
        return account.network.request(Api.functions.messages.startHistoryImport(peer: session.inputPeer, importId: session.id))
        |> mapError { _ -> StartImportError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, StartImportError> in
            if case .boolTrue = result {
                return .complete()
            } else {
                return .fail(.generic)
            }
        }
    }
}
