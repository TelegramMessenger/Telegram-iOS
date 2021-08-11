import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public extension TelegramEngine {
    final class HistoryImport {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

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
            case limitExceeded
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
        
        public func getInfo(header: String) -> Signal<ParsedInfo, GetInfoError> {
            return self.account.network.request(Api.functions.messages.checkHistoryImport(importHead: header))
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
        
        public func initSession(peerId: PeerId, file: TempBoxFile, mediaCount: Int32) -> Signal<Session, InitImportError> {
            let account = self.account
            return multipartUpload(network: self.account.network, postbox: self.account.postbox, source: .tempFile(file), encrypt: false, tag: nil, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: true, useLargerParts: true, increaseParallelParts: true, useMultiplexedRequests: false, useCompression: true)
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
                        return account.network.request(Api.functions.messages.initHistoryImport(peer: inputPeer, file: inputFile, mediaCount: mediaCount), automaticFloodWait: false)
                        |> mapError { error -> InitImportError in
                            if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                                return .chatAdminRequired
                            } else if error.errorDescription == "IMPORT_PEER_TYPE_INVALID" {
                                return .invalidChatType
                            } else if error.errorDescription == "USER_IS_BLOCKED" {
                                return .userBlocked
                            } else if error.errorDescription == "FLOOD_WAIT" {
                                return .limitExceeded
                            } else {
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
        
        public func uploadMedia(session: Session, file: TempBoxFile, disposeFileAfterDone: Bool, fileName: String, mimeType: String, type: MediaType) -> Signal<Float, UploadMediaError> {
            var forceNoBigParts = true
            guard let size = fileSize(file.path), size != 0 else {
                return .single(1.0)
            }
            if size >= 30 * 1024 * 1024 {
                forceNoBigParts = false
            }

            let account = self.account
            return multipartUpload(network: self.account.network, postbox: self.account.postbox, source: .tempFile(file), encrypt: false, tag: nil, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: forceNoBigParts, useLargerParts: true, useMultiplexedRequests: true)
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
                |> afterDisposed {
                    if disposeFileAfterDone {
                        TempBox.shared.dispose(file)
                    }
                }
            }
        }
        
        public enum StartImportError {
            case generic
        }
        
        public func startImport(session: Session) -> Signal<Never, StartImportError> {
            return self.account.network.request(Api.functions.messages.startHistoryImport(peer: session.inputPeer, importId: session.id))
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
        
        public enum CheckPeerImportResult {
            case allowed
            case alert(String)
        }
        
        public enum CheckPeerImportError {
            case generic
            case chatAdminRequired
            case invalidChatType
            case userBlocked
            case limitExceeded
            case notMutualContact
        }
        
        public func checkPeerImport(peerId: PeerId) -> Signal<CheckPeerImportResult, CheckPeerImportError> {
            let account = self.account
            return self.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            }
            |> castError(CheckPeerImportError.self)
            |> mapToSignal { peer -> Signal<CheckPeerImportResult, CheckPeerImportError> in
                guard let peer = peer else {
                    return .fail(.generic)
                }
                guard let inputPeer = apiInputPeer(peer) else {
                    return .fail(.generic)
                }
                
                return account.network.request(Api.functions.messages.checkHistoryImportPeer(peer: inputPeer))
                |> mapError { error -> CheckPeerImportError in
                    if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                        return .chatAdminRequired
                    } else if error.errorDescription == "IMPORT_PEER_TYPE_INVALID" {
                        return .invalidChatType
                    } else if error.errorDescription == "USER_IS_BLOCKED" {
                        return .userBlocked
                    } else if error.errorDescription == "USER_NOT_MUTUAL_CONTACT" {
                        return .notMutualContact
                    } else if error.errorDescription == "FLOOD_WAIT" {
                        return .limitExceeded
                    } else {
                        return .generic
                    }
                }
                |> map { result -> CheckPeerImportResult in
                    switch result {
                    case let .checkedHistoryImportPeer(confirmText):
                        if confirmText.isEmpty {
                            return .allowed
                        } else {
                            return .alert(confirmText)
                        }
                    }
                }
            }
        }
    }
}
