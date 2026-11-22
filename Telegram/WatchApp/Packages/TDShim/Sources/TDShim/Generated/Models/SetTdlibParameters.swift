//
//  SetTdlibParameters.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Sets the parameters for TDLib initialization. Works only when the current authorization state is authorizationStateWaitTdlibParameters
public struct SetTdlibParameters: Codable, Equatable, Hashable {

    /// Application identifier hash for Telegram API access, which can be obtained at https://my.telegram.org
    public let apiHash: String?

    /// Application identifier for Telegram API access, which can be obtained at https://my.telegram.org
    public let apiId: Int?

    /// Application version; must be non-empty
    public let applicationVersion: String?

    /// The path to the directory for the persistent database; if empty, the current working directory will be used
    public let databaseDirectory: String?

    /// Encryption key for the database. If the encryption key is invalid, then an error with code 401 will be returned
    public let databaseEncryptionKey: Data?

    /// Model of the device the application is being run on; must be non-empty
    public let deviceModel: String?

    /// The path to the directory for storing files; if empty, database_directory will be used
    public let filesDirectory: String?

    /// IETF language tag of the user's operating system language; must be non-empty
    public let systemLanguageCode: String?

    /// Version of the operating system the application is being run on. If empty, the version is automatically detected by TDLib
    public let systemVersion: String?

    /// Pass true to keep cache of users, basic groups, supergroups, channels and secret chats between restarts. Implies use_file_database
    public let useChatInfoDatabase: Bool?

    /// Pass true to keep information about downloaded and uploaded files between application restarts
    public let useFileDatabase: Bool?

    /// Pass true to keep cache of chats and messages between restarts. Implies use_chat_info_database
    public let useMessageDatabase: Bool?

    /// Pass true to enable support for secret chats
    public let useSecretChats: Bool?

    /// Pass true to use Telegram test environment instead of the production environment
    public let useTestDc: Bool?


    public init(
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
    ) {
        self.apiHash = apiHash
        self.apiId = apiId
        self.applicationVersion = applicationVersion
        self.databaseDirectory = databaseDirectory
        self.databaseEncryptionKey = databaseEncryptionKey
        self.deviceModel = deviceModel
        self.filesDirectory = filesDirectory
        self.systemLanguageCode = systemLanguageCode
        self.systemVersion = systemVersion
        self.useChatInfoDatabase = useChatInfoDatabase
        self.useFileDatabase = useFileDatabase
        self.useMessageDatabase = useMessageDatabase
        self.useSecretChats = useSecretChats
        self.useTestDc = useTestDc
    }
}

