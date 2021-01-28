import Foundation
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramApi

public enum ChatHistoryImport {
    public struct Session {
        fileprivate var peerId: PeerId
        fileprivate var inputPeer: Api.InputPeer
        fileprivate var id: Int64
    }
    
    public enum InitImportError {
        case generic
        case chatAdminRequired
        case invalidChatType
        case userBlocked
    }
    
    public enum ParsedInfo {
        case privateChat(title: String?)
        case group(title: String?)
        case unknown(title: String?)
    }
    
    public enum GetInfoError {
        case generic
        case parseError
    }
    
    public static func getInfo(account: Account, header: String) -> Signal<ParsedInfo, GetInfoError> {
        return account.network.request(Api.functions.messages.checkHistoryImport(importHead: header))
        |> mapError { _ -> GetInfoError in
            return .generic
        }
        |> mapToSignal { result -> Signal<ParsedInfo, GetInfoError> in
            switch result {
            case let .historyImportParsed(flags, title):
                if (flags & (1 << 0)) != 0 {
                    return .single(.privateChat(title: title))
                } else if (flags & (1 << 1)) != 0 {
                    return .single(.group(title: title))
                } else {
                    return .single(.unknown(title: title))
                }
            }
        }
    }
    
    public static func initSession(account: Account, peerId: PeerId, file: TempBoxFile, mediaCount: Int32) -> Signal<Session, InitImportError> {
        return multipartUpload(network: account.network, postbox: account.postbox, source: .tempFile(file), encrypt: false, tag: nil, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false, useLargerParts: true, increaseParallelParts: true, useMultiplexedRequests: false, useCompression: true)
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
                    |> mapError { error -> InitImportError in
                        switch error.errorDescription {
                        case "CHAT_ADMIN_REQUIRED":
                            return .chatAdminRequired
                        case "IMPORT_PEER_TYPE_INVALID":
                            return .invalidChatType
                        case "USER_IS_BLOCKED":
                            return .userBlocked
                        default:
                            return .generic
                        }
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
        case chatAdminRequired
    }
    
    public static func uploadMedia(account: Account, session: Session, file: TempBoxFile, fileName: String, mimeType: String, type: MediaType) -> Signal<Float, UploadMediaError> {
        var forceNoBigParts = true
        if let size = fileSize(file.path), size >= 30 * 1024 * 1024 {
            forceNoBigParts = false
        }
        
        return multipartUpload(network: account.network, postbox: account.postbox, source: .tempFile(file), encrypt: false, tag: nil, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: forceNoBigParts, useLargerParts: true, useMultiplexedRequests: true)
        |> mapError { _ -> UploadMediaError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Float, UploadMediaError> in
            let inputMedia: Api.InputMedia
            switch result {
            case let .inputFile(inputFile):
                switch type {
                case .photo:
                    inputMedia = .inputMediaUploadedPhoto(flags: 0, file: inputFile, stickers: nil, ttlSeconds: nil)
                case .file, .video, .sticker, .voice:
                    var attributes: [Api.DocumentAttribute] = []
                    attributes.append(.documentAttributeFilename(fileName: fileName))
                    var resolvedMimeType = mimeType
                    switch type {
                    case .video:
                        resolvedMimeType = "video/mp4"
                    case .sticker:
                        resolvedMimeType = "image/webp"
                    case .voice:
                        resolvedMimeType = "audio/ogg"
                    default:
                        break
                    }
                    inputMedia = .inputMediaUploadedDocument(flags: 0, file: inputFile, thumb: nil, mimeType: resolvedMimeType, attributes: attributes, stickers: nil, ttlSeconds: nil)
                }
            case let .progress(value):
                return .single(value)
            case .inputSecretFile:
                return .fail(.generic)
            }
            return account.network.request(Api.functions.messages.uploadImportedMedia(peer: session.inputPeer, importId: session.id, fileName: fileName, media: inputMedia))
            |> mapError { error -> UploadMediaError in
                switch error.errorDescription {
                case "CHAT_ADMIN_REQUIRED":
                    return .chatAdminRequired
                default:
                    return .generic
                }
            }
            |> mapToSignal { result -> Signal<Float, UploadMediaError> in
                return .single(1.0)
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
    
    public enum CheckPeerImportError {
        case generic
        case userIsNotMutualContact
    }
    
    public static func checkPeerImport(account: Account, peerId: PeerId) -> Signal<Never, CheckPeerImportError> {
        return account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }
        |> castError(CheckPeerImportError.self)
        |> mapToSignal { peer -> Signal<Never, CheckPeerImportError> in
            guard let peer = peer else {
                return .fail(.generic)
            }
            if let inputUser = apiInputUser(peer) {
                return account.network.request(Api.functions.users.getUsers(id: [inputUser]))
                |> mapError { _ -> CheckPeerImportError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<Never, CheckPeerImportError> in
                    guard let apiUser = result.first else {
                        return .fail(.generic)
                    }
                    switch apiUser {
                    case let .user(flags, _, _, _, _, _, _, _, _, _, _, _, _):
                        if (flags & (1 << 12)) == 0 {
                            // not mutual contact
                            return .fail(.userIsNotMutualContact)
                        }
                        return .complete()
                    case.userEmpty:
                        return .fail(.generic)
                    }
                }
            } else {
                return .complete()
            }
        }
    }
}
