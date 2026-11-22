//
//  TDLibApi.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Must be subclassed with `send` and `execute` TDLib functions implementation
public class TDLibApi {

    public let encoder = JSONEncoder()
    public let decoder = JSONDecoder()

    public init() {
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }


    /// Sends request to the TDLib client.
    public func send(query: TdQuery, completion: ((Data) -> Void)? = nil) throws {
        fatalError("send() not implemented")
    }

    /// Synchronously executes TDLib request.
    public func execute(query: TdQuery) throws -> [String:Any]? {
        fatalError("execute() not implemented")
    }


    /// Sets the parameters for TDLib initialization. Works only when the current authorization state is authorizationStateWaitTdlibParameters
    /// - Parameter apiHash: Application identifier hash for Telegram API access, which can be obtained at https://my.telegram.org
    /// - Parameter apiId: Application identifier for Telegram API access, which can be obtained at https://my.telegram.org
    /// - Parameter applicationVersion: Application version; must be non-empty
    /// - Parameter databaseDirectory: The path to the directory for the persistent database; if empty, the current working directory will be used
    /// - Parameter databaseEncryptionKey: Encryption key for the database. If the encryption key is invalid, then an error with code 401 will be returned
    /// - Parameter deviceModel: Model of the device the application is being run on; must be non-empty
    /// - Parameter filesDirectory: The path to the directory for storing files; if empty, database_directory will be used
    /// - Parameter systemLanguageCode: IETF language tag of the user's operating system language; must be non-empty
    /// - Parameter systemVersion: Version of the operating system the application is being run on. If empty, the version is automatically detected by TDLib
    /// - Parameter useChatInfoDatabase: Pass true to keep cache of users, basic groups, supergroups, channels and secret chats between restarts. Implies use_file_database
    /// - Parameter useFileDatabase: Pass true to keep information about downloaded and uploaded files between application restarts
    /// - Parameter useMessageDatabase: Pass true to keep cache of chats and messages between restarts. Implies use_chat_info_database
    /// - Parameter useSecretChats: Pass true to enable support for secret chats
    /// - Parameter useTestDc: Pass true to use Telegram test environment instead of the production environment
    public final func setTdlibParameters(
        apiHash: String?,
        apiId: Int?,
        applicationVersion: String?,
        databaseDirectory: String?,
        databaseEncryptionKey: Data?,
        deviceModel: String?,
        filesDirectory: String?,
        systemLanguageCode: String?,
        systemVersion: String?,
        useChatInfoDatabase: Bool?,
        useFileDatabase: Bool?,
        useMessageDatabase: Bool?,
        useSecretChats: Bool?,
        useTestDc: Bool?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = SetTdlibParameters(
            apiHash: apiHash,
            apiId: apiId,
            applicationVersion: applicationVersion,
            databaseDirectory: databaseDirectory,
            databaseEncryptionKey: databaseEncryptionKey,
            deviceModel: deviceModel,
            filesDirectory: filesDirectory,
            systemLanguageCode: systemLanguageCode,
            systemVersion: systemVersion,
            useChatInfoDatabase: useChatInfoDatabase,
            useFileDatabase: useFileDatabase,
            useMessageDatabase: useMessageDatabase,
            useSecretChats: useSecretChats,
            useTestDc: useTestDc
        )
        self.run(query: query, completion: completion)
    }

    /// Sets the parameters for TDLib initialization. Works only when the current authorization state is authorizationStateWaitTdlibParameters
    /// - Parameter apiHash: Application identifier hash for Telegram API access, which can be obtained at https://my.telegram.org
    /// - Parameter apiId: Application identifier for Telegram API access, which can be obtained at https://my.telegram.org
    /// - Parameter applicationVersion: Application version; must be non-empty
    /// - Parameter databaseDirectory: The path to the directory for the persistent database; if empty, the current working directory will be used
    /// - Parameter databaseEncryptionKey: Encryption key for the database. If the encryption key is invalid, then an error with code 401 will be returned
    /// - Parameter deviceModel: Model of the device the application is being run on; must be non-empty
    /// - Parameter filesDirectory: The path to the directory for storing files; if empty, database_directory will be used
    /// - Parameter systemLanguageCode: IETF language tag of the user's operating system language; must be non-empty
    /// - Parameter systemVersion: Version of the operating system the application is being run on. If empty, the version is automatically detected by TDLib
    /// - Parameter useChatInfoDatabase: Pass true to keep cache of users, basic groups, supergroups, channels and secret chats between restarts. Implies use_file_database
    /// - Parameter useFileDatabase: Pass true to keep information about downloaded and uploaded files between application restarts
    /// - Parameter useMessageDatabase: Pass true to keep cache of chats and messages between restarts. Implies use_chat_info_database
    /// - Parameter useSecretChats: Pass true to enable support for secret chats
    /// - Parameter useTestDc: Pass true to use Telegram test environment instead of the production environment
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func setTdlibParameters(
        apiHash: String?,
        apiId: Int?,
        applicationVersion: String?,
        databaseDirectory: String?,
        databaseEncryptionKey: Data?,
        deviceModel: String?,
        filesDirectory: String?,
        systemLanguageCode: String?,
        systemVersion: String?,
        useChatInfoDatabase: Bool?,
        useFileDatabase: Bool?,
        useMessageDatabase: Bool?,
        useSecretChats: Bool?,
        useTestDc: Bool?
    ) async throws -> Ok {
        let query = SetTdlibParameters(
            apiHash: apiHash,
            apiId: apiId,
            applicationVersion: applicationVersion,
            databaseDirectory: databaseDirectory,
            databaseEncryptionKey: databaseEncryptionKey,
            deviceModel: deviceModel,
            filesDirectory: filesDirectory,
            systemLanguageCode: systemLanguageCode,
            systemVersion: systemVersion,
            useChatInfoDatabase: useChatInfoDatabase,
            useFileDatabase: useFileDatabase,
            useMessageDatabase: useMessageDatabase,
            useSecretChats: useSecretChats,
            useTestDc: useTestDc
        )
        return try await self.run(query: query)
    }

    /// Requests QR code authentication by scanning a QR code on another logged in device. Works only when the current authorization state is authorizationStateWaitPhoneNumber, or if there is no pending authentication query and the current authorization state is authorizationStateWaitPremiumPurchase, authorizationStateWaitEmailAddress, authorizationStateWaitEmailCode, authorizationStateWaitCode, authorizationStateWaitRegistration, or authorizationStateWaitPassword
    /// - Parameter otherUserIds: List of user identifiers of other users currently using the application
    public final func requestQrCodeAuthentication(
        otherUserIds: [Int64]?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = RequestQrCodeAuthentication(
            otherUserIds: otherUserIds
        )
        self.run(query: query, completion: completion)
    }

    /// Requests QR code authentication by scanning a QR code on another logged in device. Works only when the current authorization state is authorizationStateWaitPhoneNumber, or if there is no pending authentication query and the current authorization state is authorizationStateWaitPremiumPurchase, authorizationStateWaitEmailAddress, authorizationStateWaitEmailCode, authorizationStateWaitCode, authorizationStateWaitRegistration, or authorizationStateWaitPassword
    /// - Parameter otherUserIds: List of user identifiers of other users currently using the application
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func requestQrCodeAuthentication(otherUserIds: [Int64]?) async throws -> Ok {
        let query = RequestQrCodeAuthentication(
            otherUserIds: otherUserIds
        )
        return try await self.run(query: query)
    }

    /// Checks the 2-step verification password for correctness. Works only when the current authorization state is authorizationStateWaitPassword
    /// - Parameter password: The 2-step verification password to check
    public final func checkAuthenticationPassword(
        password: String?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = CheckAuthenticationPassword(
            password: password
        )
        self.run(query: query, completion: completion)
    }

    /// Checks the 2-step verification password for correctness. Works only when the current authorization state is authorizationStateWaitPassword
    /// - Parameter password: The 2-step verification password to check
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func checkAuthenticationPassword(password: String?) async throws -> Ok {
        let query = CheckAuthenticationPassword(
            password: password
        )
        return try await self.run(query: query)
    }

    /// Closes the TDLib instance after a proper logout. Requires an available network connection. All local data will be destroyed. After the logout completes, updateAuthorizationState with authorizationStateClosed will be sent
    public final func logOut(completion: @escaping (Result<Ok, Swift.Error>) -> Void) throws {
        let query = LogOut()
        self.run(query: query, completion: completion)
    }

    /// Closes the TDLib instance after a proper logout. Requires an available network connection. All local data will be destroyed. After the logout completes, updateAuthorizationState with authorizationStateClosed will be sent
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func logOut() async throws -> Ok {
        let query = LogOut()
        return try await self.run(query: query)
    }

    /// Closes the TDLib instance. All databases will be flushed to disk and properly closed. After the close completes, updateAuthorizationState with authorizationStateClosed will be sent. Can be called before initialization
    public final func close(completion: @escaping (Result<Ok, Swift.Error>) -> Void) throws {
        let query = Close()
        self.run(query: query, completion: completion)
    }

    /// Closes the TDLib instance. All databases will be flushed to disk and properly closed. After the close completes, updateAuthorizationState with authorizationStateClosed will be sent. Can be called before initialization
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func close() async throws -> Ok {
        let query = Close()
        return try await self.run(query: query)
    }

    /// Closes the TDLib instance, destroying all local data without a proper logout. The current user session will remain in the list of all active sessions. All local data will be destroyed. After the destruction completes updateAuthorizationState with authorizationStateClosed will be sent. Can be called before authorization
    public final func destroy(completion: @escaping (Result<Ok, Swift.Error>) -> Void) throws {
        let query = Destroy()
        self.run(query: query, completion: completion)
    }

    /// Closes the TDLib instance, destroying all local data without a proper logout. The current user session will remain in the list of all active sessions. All local data will be destroyed. After the destruction completes updateAuthorizationState with authorizationStateClosed will be sent. Can be called before authorization
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func destroy() async throws -> Ok {
        let query = Destroy()
        return try await self.run(query: query)
    }

    /// Returns the current user
    /// - Returns: The current user
    public final func getMe(completion: @escaping (Result<User, Swift.Error>) -> Void) throws {
        let query = GetMe()
        self.run(query: query, completion: completion)
    }

    /// Returns the current user
    /// - Returns: The current user
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public final func getMe() async throws -> User {
        let query = GetMe()
        return try await self.run(query: query)
    }

    /// Loads more chats from a chat list. The loaded chats and their positions in the chat list will be sent through updates. Chats are sorted by the pair (chat.position.order, chat.id) in descending order. Returns a 404 error if all chats have been loaded
    /// - Parameter chatList: The chat list in which to load chats; pass null to load chats from the main chat list
    /// - Parameter limit: The maximum number of chats to be loaded. For optimal performance, the number of loaded chats is chosen by TDLib and can be smaller than the specified limit, even if the end of the list is not reached
    /// - Returns: A 404 error if all chats have been loaded
    public final func loadChats(
        chatList: ChatList?,
        limit: Int?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = LoadChats(
            chatList: chatList,
            limit: limit
        )
        self.run(query: query, completion: completion)
    }

    /// Loads more chats from a chat list. The loaded chats and their positions in the chat list will be sent through updates. Chats are sorted by the pair (chat.position.order, chat.id) in descending order. Returns a 404 error if all chats have been loaded
    /// - Parameter chatList: The chat list in which to load chats; pass null to load chats from the main chat list
    /// - Parameter limit: The maximum number of chats to be loaded. For optimal performance, the number of loaded chats is chosen by TDLib and can be smaller than the specified limit, even if the end of the list is not reached
    /// - Returns: A 404 error if all chats have been loaded
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func loadChats(
        chatList: ChatList?,
        limit: Int?
    ) async throws -> Ok {
        let query = LoadChats(
            chatList: chatList,
            limit: limit
        )
        return try await self.run(query: query)
    }

    /// Returns messages in a chat. The messages are returned in reverse chronological order (i.e., in order of decreasing message_id). For optimal performance, the number of returned messages is chosen by TDLib. This is an offline method if only_local is true
    /// - Parameter chatId: Chat identifier
    /// - Parameter fromMessageId: Identifier of the message starting from which history must be fetched; use 0 to get results from the last message
    /// - Parameter limit: The maximum number of messages to be returned; must be positive and can't be greater than 100. If the offset is negative, then the limit must be greater than or equal to -offset. For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
    /// - Parameter offset: Specify 0 to get results from exactly the message from_message_id or a negative number from -99 to -1 to get additionally -offset newer messages
    /// - Parameter onlyLocal: Pass true to get only messages that are available without sending network requests
    /// - Returns: Messages in a chat. The messages are returned in reverse chronological order (i.e., in order of decreasing message_id). For optimal performance, the number of returned messages is chosen by TDLib
    public final func getChatHistory(
        chatId: Int64?,
        fromMessageId: Int64?,
        limit: Int?,
        offset: Int?,
        onlyLocal: Bool?,
        completion: @escaping (Result<Messages, Swift.Error>) -> Void
    ) throws {
        let query = GetChatHistory(
            chatId: chatId,
            fromMessageId: fromMessageId,
            limit: limit,
            offset: offset,
            onlyLocal: onlyLocal
        )
        self.run(query: query, completion: completion)
    }

    /// Returns messages in a chat. The messages are returned in reverse chronological order (i.e., in order of decreasing message_id). For optimal performance, the number of returned messages is chosen by TDLib. This is an offline method if only_local is true
    /// - Parameter chatId: Chat identifier
    /// - Parameter fromMessageId: Identifier of the message starting from which history must be fetched; use 0 to get results from the last message
    /// - Parameter limit: The maximum number of messages to be returned; must be positive and can't be greater than 100. If the offset is negative, then the limit must be greater than or equal to -offset. For optimal performance, the number of returned messages is chosen by TDLib and can be smaller than the specified limit
    /// - Parameter offset: Specify 0 to get results from exactly the message from_message_id or a negative number from -99 to -1 to get additionally -offset newer messages
    /// - Parameter onlyLocal: Pass true to get only messages that are available without sending network requests
    /// - Returns: Messages in a chat. The messages are returned in reverse chronological order (i.e., in order of decreasing message_id). For optimal performance, the number of returned messages is chosen by TDLib
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public final func getChatHistory(
        chatId: Int64?,
        fromMessageId: Int64?,
        limit: Int?,
        offset: Int?,
        onlyLocal: Bool?
    ) async throws -> Messages {
        let query = GetChatHistory(
            chatId: chatId,
            fromMessageId: fromMessageId,
            limit: limit,
            offset: offset,
            onlyLocal: onlyLocal
        )
        return try await self.run(query: query)
    }

    /// Sends a message. Returns the sent message
    /// - Parameter chatId: Target chat
    /// - Parameter inputMessageContent: The content of the message to be sent
    /// - Parameter options: Options to be used to send the message; pass null to use default options
    /// - Parameter replyMarkup: Markup for replying to the message; pass null if none; for bots only
    /// - Parameter replyTo: Information about the message or story to be replied; pass null if none
    /// - Parameter topicId: Topic in which the message will be sent; pass null if none
    /// - Returns: The sent message
    public final func sendMessage(
        chatId: Int64?,
        inputMessageContent: InputMessageContent?,
        options: MessageSendOptions?,
        replyMarkup: ReplyMarkup?,
        replyTo: InputMessageReplyTo?,
        topicId: MessageTopic?,
        completion: @escaping (Result<Message, Swift.Error>) -> Void
    ) throws {
        let query = SendMessage(
            chatId: chatId,
            inputMessageContent: inputMessageContent,
            options: options,
            replyMarkup: replyMarkup,
            replyTo: replyTo,
            topicId: topicId
        )
        self.run(query: query, completion: completion)
    }

    /// Sends a message. Returns the sent message
    /// - Parameter chatId: Target chat
    /// - Parameter inputMessageContent: The content of the message to be sent
    /// - Parameter options: Options to be used to send the message; pass null to use default options
    /// - Parameter replyMarkup: Markup for replying to the message; pass null if none; for bots only
    /// - Parameter replyTo: Information about the message or story to be replied; pass null if none
    /// - Parameter topicId: Topic in which the message will be sent; pass null if none
    /// - Returns: The sent message
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public final func sendMessage(
        chatId: Int64?,
        inputMessageContent: InputMessageContent?,
        options: MessageSendOptions?,
        replyMarkup: ReplyMarkup?,
        replyTo: InputMessageReplyTo?,
        topicId: MessageTopic?
    ) async throws -> Message {
        let query = SendMessage(
            chatId: chatId,
            inputMessageContent: inputMessageContent,
            options: options,
            replyMarkup: replyMarkup,
            replyTo: replyTo,
            topicId: topicId
        )
        return try await self.run(query: query)
    }

    /// Changes the user answer to a poll
    /// - Parameter chatId: Identifier of the chat to which the poll belongs
    /// - Parameter messageId: Identifier of the message containing the poll
    /// - Parameter optionIds: 0-based identifiers of answer options, chosen by the user. User can choose more than 1 answer option only is the poll allows multiple answers
    public final func setPollAnswer(
        chatId: Int64?,
        messageId: Int64?,
        optionIds: [Int]?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = SetPollAnswer(
            chatId: chatId,
            messageId: messageId,
            optionIds: optionIds
        )
        self.run(query: query, completion: completion)
    }

    /// Changes the user answer to a poll
    /// - Parameter chatId: Identifier of the chat to which the poll belongs
    /// - Parameter messageId: Identifier of the message containing the poll
    /// - Parameter optionIds: 0-based identifiers of answer options, chosen by the user. User can choose more than 1 answer option only is the poll allows multiple answers
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func setPollAnswer(
        chatId: Int64?,
        messageId: Int64?,
        optionIds: [Int]?
    ) async throws -> Ok {
        let query = SetPollAnswer(
            chatId: chatId,
            messageId: messageId,
            optionIds: optionIds
        )
        return try await self.run(query: query)
    }

    /// Informs TDLib that the chat is opened by the user. Many useful activities depend on the chat being opened or closed (e.g., in supergroups and channels all updates are received only for opened chats)
    /// - Parameter chatId: Chat identifier
    public final func openChat(
        chatId: Int64?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = OpenChat(
            chatId: chatId
        )
        self.run(query: query, completion: completion)
    }

    /// Informs TDLib that the chat is opened by the user. Many useful activities depend on the chat being opened or closed (e.g., in supergroups and channels all updates are received only for opened chats)
    /// - Parameter chatId: Chat identifier
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func openChat(chatId: Int64?) async throws -> Ok {
        let query = OpenChat(
            chatId: chatId
        )
        return try await self.run(query: query)
    }

    /// Informs TDLib that the chat is closed by the user. Many useful activities depend on the chat being opened or closed
    /// - Parameter chatId: Chat identifier
    public final func closeChat(
        chatId: Int64?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = CloseChat(
            chatId: chatId
        )
        self.run(query: query, completion: completion)
    }

    /// Informs TDLib that the chat is closed by the user. Many useful activities depend on the chat being opened or closed
    /// - Parameter chatId: Chat identifier
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func closeChat(chatId: Int64?) async throws -> Ok {
        let query = CloseChat(
            chatId: chatId
        )
        return try await self.run(query: query)
    }

    /// Informs TDLib that messages are being viewed by the user. Sponsored messages must be marked as viewed only when the entire text of the message is shown on the screen (excluding the button). Many useful activities depend on whether the messages are currently being viewed or not (e.g., marking messages as read, incrementing a view counter, updating a view counter, removing deleted messages in supergroups and channels)
    /// - Parameter chatId: Chat identifier
    /// - Parameter forceRead: Pass true to mark as read the specified messages even if the chat is closed
    /// - Parameter messageIds: The identifiers of the messages being viewed
    /// - Parameter source: Source of the message view; pass null to guess the source based on chat open state
    public final func viewMessages(
        chatId: Int64?,
        forceRead: Bool?,
        messageIds: [Int64]?,
        source: MessageSource?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = ViewMessages(
            chatId: chatId,
            forceRead: forceRead,
            messageIds: messageIds,
            source: source
        )
        self.run(query: query, completion: completion)
    }

    /// Informs TDLib that messages are being viewed by the user. Sponsored messages must be marked as viewed only when the entire text of the message is shown on the screen (excluding the button). Many useful activities depend on whether the messages are currently being viewed or not (e.g., marking messages as read, incrementing a view counter, updating a view counter, removing deleted messages in supergroups and channels)
    /// - Parameter chatId: Chat identifier
    /// - Parameter forceRead: Pass true to mark as read the specified messages even if the chat is closed
    /// - Parameter messageIds: The identifiers of the messages being viewed
    /// - Parameter source: Source of the message view; pass null to guess the source based on chat open state
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func viewMessages(
        chatId: Int64?,
        forceRead: Bool?,
        messageIds: [Int64]?,
        source: MessageSource?
    ) async throws -> Ok {
        let query = ViewMessages(
            chatId: chatId,
            forceRead: forceRead,
            messageIds: messageIds,
            source: source
        )
        return try await self.run(query: query)
    }

    /// Changes the draft message in a chat or a topic
    /// - Parameter chatId: Chat identifier
    /// - Parameter draftMessage: New draft message; pass null to remove the draft. All files in draft message content must be of the type inputFileLocal. Media thumbnails and captions are ignored
    /// - Parameter topicId: Topic in which the draft will be changed; pass null to change the draft for the chat itself
    public final func setChatDraftMessage(
        chatId: Int64?,
        draftMessage: DraftMessage?,
        topicId: MessageTopic?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = SetChatDraftMessage(
            chatId: chatId,
            draftMessage: draftMessage,
            topicId: topicId
        )
        self.run(query: query, completion: completion)
    }

    /// Changes the draft message in a chat or a topic
    /// - Parameter chatId: Chat identifier
    /// - Parameter draftMessage: New draft message; pass null to remove the draft. All files in draft message content must be of the type inputFileLocal. Media thumbnails and captions are ignored
    /// - Parameter topicId: Topic in which the draft will be changed; pass null to change the draft for the chat itself
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func setChatDraftMessage(
        chatId: Int64?,
        draftMessage: DraftMessage?,
        topicId: MessageTopic?
    ) async throws -> Ok {
        let query = SetChatDraftMessage(
            chatId: chatId,
            draftMessage: draftMessage,
            topicId: topicId
        )
        return try await self.run(query: query)
    }

    /// Downloads a file from the cloud. Download progress and completion of the download will be notified through updateFile updates
    /// - Parameter fileId: Identifier of the file to download
    /// - Parameter limit: Number of bytes which need to be downloaded starting from the "offset" position before the download will automatically be canceled; use 0 to download without a limit
    /// - Parameter offset: The starting position from which the file needs to be downloaded
    /// - Parameter priority: Priority of the download (1-32). The higher the priority, the earlier the file will be downloaded. If the priorities of two files are equal, then the last one for which downloadFile/addFileToDownloads was called will be downloaded first
    /// - Parameter synchronous: Pass true to return response only after the file download has succeeded, has failed, has been canceled, or a new downloadFile request with different offset/limit parameters was sent; pass false to return file state immediately, just after the download has been started
    public final func downloadFile(
        fileId: Int?,
        limit: Int64?,
        offset: Int64?,
        priority: Int?,
        synchronous: Bool?,
        completion: @escaping (Result<File, Swift.Error>) -> Void
    ) throws {
        let query = DownloadFile(
            fileId: fileId,
            limit: limit,
            offset: offset,
            priority: priority,
            synchronous: synchronous
        )
        self.run(query: query, completion: completion)
    }

    /// Downloads a file from the cloud. Download progress and completion of the download will be notified through updateFile updates
    /// - Parameter fileId: Identifier of the file to download
    /// - Parameter limit: Number of bytes which need to be downloaded starting from the "offset" position before the download will automatically be canceled; use 0 to download without a limit
    /// - Parameter offset: The starting position from which the file needs to be downloaded
    /// - Parameter priority: Priority of the download (1-32). The higher the priority, the earlier the file will be downloaded. If the priorities of two files are equal, then the last one for which downloadFile/addFileToDownloads was called will be downloaded first
    /// - Parameter synchronous: Pass true to return response only after the file download has succeeded, has failed, has been canceled, or a new downloadFile request with different offset/limit parameters was sent; pass false to return file state immediately, just after the download has been started
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public final func downloadFile(
        fileId: Int?,
        limit: Int64?,
        offset: Int64?,
        priority: Int?,
        synchronous: Bool?
    ) async throws -> File {
        let query = DownloadFile(
            fileId: fileId,
            limit: limit,
            offset: offset,
            priority: priority,
            synchronous: synchronous
        )
        return try await self.run(query: query)
    }

    /// Stops the downloading of a file. If a file has already been downloaded, does nothing
    /// - Parameter fileId: Identifier of a file to stop downloading
    /// - Parameter onlyIfPending: Pass true to stop downloading only if it hasn't been started, i.e. request hasn't been sent to server
    public final func cancelDownloadFile(
        fileId: Int?,
        onlyIfPending: Bool?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = CancelDownloadFile(
            fileId: fileId,
            onlyIfPending: onlyIfPending
        )
        self.run(query: query, completion: completion)
    }

    /// Stops the downloading of a file. If a file has already been downloaded, does nothing
    /// - Parameter fileId: Identifier of a file to stop downloading
    /// - Parameter onlyIfPending: Pass true to stop downloading only if it hasn't been started, i.e. request hasn't been sent to server
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func cancelDownloadFile(
        fileId: Int?,
        onlyIfPending: Bool?
    ) async throws -> Ok {
        let query = CancelDownloadFile(
            fileId: fileId,
            onlyIfPending: onlyIfPending
        )
        return try await self.run(query: query)
    }

    /// Returns a list of installed sticker sets
    /// - Parameter stickerType: Type of the sticker sets to return
    /// - Returns: A list of installed sticker sets
    public final func getInstalledStickerSets(
        stickerType: StickerType?,
        completion: @escaping (Result<StickerSets, Swift.Error>) -> Void
    ) throws {
        let query = GetInstalledStickerSets(
            stickerType: stickerType
        )
        self.run(query: query, completion: completion)
    }

    /// Returns a list of installed sticker sets
    /// - Parameter stickerType: Type of the sticker sets to return
    /// - Returns: A list of installed sticker sets
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public final func getInstalledStickerSets(stickerType: StickerType?) async throws -> StickerSets {
        let query = GetInstalledStickerSets(
            stickerType: stickerType
        )
        return try await self.run(query: query)
    }

    /// Returns information about a sticker set by its identifier
    /// - Parameter setId: Identifier of the sticker set
    /// - Returns: Information about a sticker set by its identifier
    public final func getStickerSet(
        setId: TdInt64?,
        completion: @escaping (Result<StickerSet, Swift.Error>) -> Void
    ) throws {
        let query = GetStickerSet(
            setId: setId
        )
        self.run(query: query, completion: completion)
    }

    /// Returns information about a sticker set by its identifier
    /// - Parameter setId: Identifier of the sticker set
    /// - Returns: Information about a sticker set by its identifier
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public final func getStickerSet(setId: TdInt64?) async throws -> StickerSet {
        let query = GetStickerSet(
            setId: setId
        )
        return try await self.run(query: query)
    }

    /// Returns a list of recently used stickers
    /// - Parameter isAttached: Pass true to return stickers and masks that were recently attached to photos or video files; pass false to return recently sent stickers
    /// - Returns: A list of recently used stickers
    public final func getRecentStickers(
        isAttached: Bool?,
        completion: @escaping (Result<Stickers, Swift.Error>) -> Void
    ) throws {
        let query = GetRecentStickers(
            isAttached: isAttached
        )
        self.run(query: query, completion: completion)
    }

    /// Returns a list of recently used stickers
    /// - Parameter isAttached: Pass true to return stickers and masks that were recently attached to photos or video files; pass false to return recently sent stickers
    /// - Returns: A list of recently used stickers
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public final func getRecentStickers(isAttached: Bool?) async throws -> Stickers {
        let query = GetRecentStickers(
            isAttached: isAttached
        )
        return try await self.run(query: query)
    }

    /// Returns favorite stickers
    /// - Returns: Favorite stickers
    public final func getFavoriteStickers(completion: @escaping (Result<Stickers, Swift.Error>) -> Void) throws {
        let query = GetFavoriteStickers()
        self.run(query: query, completion: completion)
    }

    /// Returns favorite stickers
    /// - Returns: Favorite stickers
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public final func getFavoriteStickers() async throws -> Stickers {
        let query = GetFavoriteStickers()
        return try await self.run(query: query)
    }

    /// Returns the value of an option by its name. (Check the list of available options on https://core.telegram.org/tdlib/options.) Can be called before authorization. Can be called synchronously for options "version" and "commit_hash"
    /// - Parameter name: The name of the option
    /// - Returns: The value of an option by its name
    public final func getOption(
        name: String?,
        completion: @escaping (Result<OptionValue, Swift.Error>) -> Void
    ) throws {
        let query = GetOption(
            name: name
        )
        self.run(query: query, completion: completion)
    }

    /// Returns the value of an option by its name. (Check the list of available options on https://core.telegram.org/tdlib/options.) Can be called before authorization. Can be called synchronously for options "version" and "commit_hash"
    /// - Parameter name: The name of the option
    /// - Returns: The value of an option by its name
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public final func getOption(name: String?) async throws -> OptionValue {
        let query = GetOption(
            name: name
        )
        return try await self.run(query: query)
    }

    /// Sets the value of an option. (Check the list of available options on https://core.telegram.org/tdlib/options.) Only writable options can be set. Can be called before authorization
    /// - Parameter name: The name of the option
    /// - Parameter value: The new value of the option; pass null to reset option value to a default value
    public final func setOption(
        name: String?,
        value: OptionValue?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = SetOption(
            name: name,
            value: value
        )
        self.run(query: query, completion: completion)
    }

    /// Sets the value of an option. (Check the list of available options on https://core.telegram.org/tdlib/options.) Only writable options can be set. Can be called before authorization
    /// - Parameter name: The name of the option
    /// - Parameter value: The new value of the option; pass null to reset option value to a default value
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func setOption(
        name: String?,
        value: OptionValue?
    ) async throws -> Ok {
        let query = SetOption(
            name: name,
            value: value
        )
        return try await self.run(query: query)
    }

    /// Sets the verbosity level of the internal logging of TDLib. Can be called synchronously
    /// - Parameter newVerbosityLevel: New value of the verbosity level for logging. Value 0 corresponds to fatal errors, value 1 corresponds to errors, value 2 corresponds to warnings and debug warnings, value 3 corresponds to informational, value 4 corresponds to debug, value 5 corresponds to verbose debug, value greater than 5 and up to 1023 can be used to enable even more logging
    public final func setLogVerbosityLevel(
        newVerbosityLevel: Int?,
        completion: @escaping (Result<Ok, Swift.Error>) -> Void
    ) throws {
        let query = SetLogVerbosityLevel(
            newVerbosityLevel: newVerbosityLevel
        )
        self.run(query: query, completion: completion)
    }

    /// Sets the verbosity level of the internal logging of TDLib. Can be called synchronously
    /// - Parameter newVerbosityLevel: New value of the verbosity level for logging. Value 0 corresponds to fatal errors, value 1 corresponds to errors, value 2 corresponds to warnings and debug warnings, value 3 corresponds to informational, value 4 corresponds to debug, value 5 corresponds to verbose debug, value greater than 5 and up to 1023 can be used to enable even more logging
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    public final func setLogVerbosityLevel(newVerbosityLevel: Int?) async throws -> Ok {
        let query = SetLogVerbosityLevel(
            newVerbosityLevel: newVerbosityLevel
        )
        return try await self.run(query: query)
    }


    private final func run<Q, R>(
        query: Q,
        completion: @escaping (Result<R, Swift.Error>) -> Void)
        where Q: Codable, R: Codable {

        let dto = DTO(query, encoder: self.encoder)
        do {
            try self.send(query: dto) { [weak self] result in
                guard let strongSelf = self else { return }
                if let error = try? strongSelf.decoder.decode(DTO<TDError>.self, from: result) {
                    completion(.failure(error.payload))
                } else {
                    let response = strongSelf.decoder.tryDecode(DTO<R>.self, from: result)
                    completion(response.map { $0.payload })
                }
            }
        } catch let err as TDError {
            completion( .failure(err))
        } catch let any {
            let err = TDError(code: 500, message: any.localizedDescription)
            completion( .failure(err))
        }
    }


    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    private final func run<Q, R>(query: Q) async throws -> R where Q: Codable, R: Codable {
        let dto = DTO(query, encoder: self.encoder)
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try self.send(query: dto) { result in
                    if let error = try? self.decoder.decode(DTO<TDError>.self, from: result) {
                        continuation.resume(with: .failure(error.payload))
                    } else {
                        let response = self.decoder.tryDecode(DTO<R>.self, from: result)
                        continuation.resume(with: response.map { $0.payload })
                    }
                }
            } catch let err as TDError {
                continuation.resume(with: .failure(err))
            } catch let any {
                let err = TDError(code: 500, message: any.localizedDescription)
                continuation.resume(with: .failure(err))
            }
        }
    }
}
