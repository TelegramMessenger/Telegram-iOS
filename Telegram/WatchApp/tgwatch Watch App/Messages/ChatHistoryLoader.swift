import Foundation
import OSLog
import TDShim

/// Single seam between `ChatHistoryStore` and TDLib. Tests inject a fake; production
/// uses `TDLibChatHistoryLoader`.
///
/// `openChat` / `closeChat` notify TDLib that the chat is being viewed, which is required
/// for supergroup / channel updates to flow. `loadHistory` returns messages in reverse
/// chronological order (TDLib's contract); the store sorts ascending for display.
///
/// `downloadFile` / `cancelDownloadFile` drive viewport-based photo downloading. Both are
/// idempotent: TDLib short-circuits if the file is already on disk (download) or already
/// complete (cancel).
protocol ChatHistoryLoader: Sendable {
    func openChat(chatId: Int64) async throws
    func closeChat(chatId: Int64) async throws
    /// `offset`: pass 0 for "messages strictly older than fromMessageId" (default
    /// pagination call). Pass a negative N to additionally include N messages
    /// NEWER than fromMessageId — used for the open-at-unread anchor fetch and
    /// for newer-direction pagination. Mirrors TDLib's `getChatHistory` semantics.
    func loadHistory(chatId: Int64, fromMessageId: Int64, offset: Int, limit: Int) async throws -> [Message]
    func downloadFile(fileId: Int, priority: Int) async throws -> File
    func cancelDownloadFile(fileId: Int) async throws
    func sendText(chatId: Int64, text: String) async throws -> Message
    func sendVoiceNote(chatId: Int64, fileURL: URL, duration: Int, waveform: Data) async throws -> Message
    func setChatDraftMessage(chatId: Int64, draftText: String) async throws
    /// Marks the given message ids as viewed (read). `forceRead: false` matches
    /// the "user is currently looking at the chat" semantics — TDLib uses the
    /// `openChat` state to decide whether to actually mark read.
    func viewMessages(chatId: Int64, messageIds: [Int64], forceRead: Bool) async throws
    /// Casts (or changes) the current user's answer to a poll. `optionIds` are
    /// 0-based option positions; multiple ids only when the poll allows it.
    func setPollAnswer(chatId: Int64, messageId: Int64, optionIds: [Int]) async throws
    /// Sends an installed sticker by its remote file id (`InputFileRemote`).
    /// No local download is required — TDLib resolves the remote reference.
    func sendSticker(chatId: Int64, remoteFileId: String, emoji: String, width: Int, height: Int) async throws -> Message
    /// Sends the given coordinate as a static location message (`livePeriod` 0).
    func sendLocation(chatId: Int64, latitude: Double, longitude: Double) async throws -> Message
}

struct TDLibChatHistoryLoader: ChatHistoryLoader {
    let client: TDLibClient

    func openChat(chatId: Int64) async throws {
        _ = try await client.openChat(chatId: chatId)
    }

    func closeChat(chatId: Int64) async throws {
        _ = try await client.closeChat(chatId: chatId)
    }

    func loadHistory(chatId: Int64, fromMessageId: Int64, offset: Int, limit: Int) async throws -> [Message] {
        // Resilient path: skip the atomic `client.getChatHistory(...)` decode (which
        // throws on the first message TDLibKit can't model) and decode messages
        // one-by-one, dropping any that fail. TDLib evolves faster than the pinned
        // TDLibKit version, so some chats contain message types (e.g. `messageGift`
        // with a `gift.background` that TDLibKit expects but the server no longer
        // provides) that would otherwise break the entire chat load.
        try await loadHistoryResilient(
            chatId: chatId,
            fromMessageId: fromMessageId,
            offset: offset,
            limit: limit
        )
    }

    private func loadHistoryResilient(
        chatId: Int64,
        fromMessageId: Int64,
        offset: Int,
        limit: Int
    ) async throws -> [Message] {
        let query = GetChatHistory(
            chatId: chatId,
            fromMessageId: fromMessageId,
            limit: limit,
            offset: offset,
            onlyLocal: false
        )
        let dto = DTO(query, encoder: client.encoder)
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            do {
                try client.send(query: dto) { responseData in
                    continuation.resume(returning: responseData)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        return decodeMessagesLeniently(data, chatId: chatId)
    }

    private func decodeMessagesLeniently(_ data: Data, chatId: Int64) -> [Message] {
        let logger = Logger(subsystem: "org.telegram.TelegramWatch", category: "chathistory")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("getChatHistory chatId=\(chatId, privacy: .public) — response was not JSON object")
            return []
        }
        if let type = json["@type"] as? String, type == "error" {
            logger.warning("getChatHistory chatId=\(chatId, privacy: .public) — TDLib error response: \(String(describing: json), privacy: .public)")
            return []
        }
        guard let rawMessages = json["messages"] as? [[String: Any]] else {
            return []
        }
        var decoded: [Message] = []
        decoded.reserveCapacity(rawMessages.count)
        for (idx, raw) in rawMessages.enumerated() {
            // Re-serialize each message dict to Data so TDLibKit's decoder can
            // consume it the same way it would the full Messages response.
            guard let perMessageData = try? JSONSerialization.data(withJSONObject: raw) else {
                logger.warning("getChatHistory chatId=\(chatId, privacy: .public) — re-serialize failed at index=\(idx, privacy: .public)")
                continue
            }
            do {
                let m = try client.decoder.decode(Message.self, from: perMessageData)
                decoded.append(m)
            } catch {
                logger.warning("getChatHistory chatId=\(chatId, privacy: .public) — skipping message index=\(idx, privacy: .public) due to decode error: \(String(describing: error), privacy: .public)")
            }
        }
        return decoded
    }

    func downloadFile(fileId: Int, priority: Int) async throws -> File {
        // synchronous=false → TDLib returns immediately and streams progress via updateFile.
        try await client.downloadFile(
            fileId: fileId,
            limit: 0,
            offset: 0,
            priority: priority,
            synchronous: false
        )
    }

    func cancelDownloadFile(fileId: Int) async throws {
        // onlyIfPending=false → cancel even if active.
        _ = try await client.cancelDownloadFile(fileId: fileId, onlyIfPending: false)
    }

    func sendText(chatId: Int64, text: String) async throws -> Message {
        try await client.sendMessage(
            chatId: chatId,
            inputMessageContent: .inputMessageText(InputMessageText(
                clearDraft: true,
                linkPreviewOptions: nil,
                text: FormattedText(entities: [], text: text)
            )),
            options: nil,
            replyMarkup: nil,
            replyTo: nil,
            topicId: nil
        )
    }

    func sendVoiceNote(chatId: Int64, fileURL: URL, duration: Int, waveform: Data) async throws -> Message {
        try await client.sendMessage(
            chatId: chatId,
            inputMessageContent: .inputMessageVoiceNote(InputMessageVoiceNote(
                caption: nil,
                duration: duration,
                selfDestructType: nil,
                voiceNote: .inputFileLocal(InputFileLocal(path: fileURL.path)),
                waveform: waveform
            )),
            options: nil,
            replyMarkup: nil,
            replyTo: nil,
            topicId: nil
        )
    }

    func setChatDraftMessage(chatId: Int64, draftText: String) async throws {
        let draft: DraftMessage? = draftText.isEmpty ? nil : DraftMessage(
            date: Int(Foundation.Date().timeIntervalSince1970),
            effectId: 0,
            inputMessageText: .inputMessageText(InputMessageText(
                clearDraft: false,
                linkPreviewOptions: nil,
                text: FormattedText(entities: [], text: draftText)
            )),
            replyTo: nil,
            suggestedPostInfo: nil
        )
        _ = try await client.setChatDraftMessage(
            chatId: chatId,
            draftMessage: draft,
            topicId: nil
        )
    }

    func viewMessages(chatId: Int64, messageIds: [Int64], forceRead: Bool) async throws {
        _ = try await client.viewMessages(
            chatId: chatId,
            forceRead: forceRead,
            messageIds: messageIds,
            source: nil
        )
    }

    func setPollAnswer(chatId: Int64, messageId: Int64, optionIds: [Int]) async throws {
        _ = try await client.setPollAnswer(chatId: chatId, messageId: messageId, optionIds: optionIds)
    }

    func sendSticker(chatId: Int64, remoteFileId: String, emoji: String, width: Int, height: Int) async throws -> Message {
        try await client.sendMessage(
            chatId: chatId,
            inputMessageContent: .inputMessageSticker(InputMessageSticker(
                emoji: emoji,
                height: height,
                sticker: .inputFileRemote(InputFileRemote(id: remoteFileId)),
                thumbnail: nil,
                width: width
            )),
            options: nil,
            replyMarkup: nil,
            replyTo: nil,
            topicId: nil
        )
    }

    func sendLocation(chatId: Int64, latitude: Double, longitude: Double) async throws -> Message {
        try await client.sendMessage(
            chatId: chatId,
            inputMessageContent: .inputMessageLocation(InputMessageLocation(
                heading: 0,
                livePeriod: 0,
                location: Location(horizontalAccuracy: 0, latitude: latitude, longitude: longitude),
                proximityAlertRadius: 0
            )),
            options: nil,
            replyMarkup: nil,
            replyTo: nil,
            topicId: nil
        )
    }
}
