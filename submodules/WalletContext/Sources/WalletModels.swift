import Foundation
import TelegramCore

let walletPendingTransferUILifetime: Int32 = 90

@available(macOS 10.15, *)
func walletPendingTransferUIExpirationTimestamp(from timestamp: Int32) -> Int32 {
    return Int32(clamping: Int64(timestamp) + Int64(walletPendingTransferUILifetime))
}

@available(macOS 10.15, *)
public extension WalletContext {
    enum FiatCurrency: Int32, CaseIterable, Codable, Hashable, Sendable {
        case usd, eur, rub, cny
        case aed, afn, all, amd, ars, aud
        case azn, bam, bdt, bgn, bhd, bnd
        case bob, brl, byn, cad, chf, clp
        case cop, crc, czk, dkk, dop, dzd
        case egp, etb, gbp, gel, ghs, gtq
        case hkd, hnl, hrk, huf, idr, ils
        case inr, iqd, irr, isk, jmd, jod
        case jpy, kes, kgs, krw, kzt, lbp
        case lkr, mad, mdl, mmk, mnt, mop
        case mur, mvr, mxn, myr, mzn, ngn
        case nio, nok, npr, nzd, pab, pen
        case php, pkr, pln, pyg, qar, ron
        case rsd, sar, sek, sgd, syp, thb
        case tjs, tryCurrency, ttd, twd, tzs
        case uah, ugx, uyu, uzs, vnd, yer
        case zar

        public var code: String {
            if self == .tryCurrency {
                return "TRY"
            }
            return String(describing: self).uppercased()
        }

        public var symbol: String {
            switch self {
            case .usd:
                return "$"
            case .eur:
                return "€"
            case .rub:
                return "₽"
            case .cny:
                return "¥"
            case .afn:
                return "؋"
            case .amd:
                return "֏"
            case .aud:
                return "A$"
            case .azn:
                return "₼"
            case .bdt:
                return "৳"
            case .brl:
                return "R$"
            case .cad:
                return "CA$"
            case .crc:
                return "₡"
            case .egp:
                return "E£"
            case .gbp:
                return "£"
            case .gel:
                return "₾"
            case .ghs:
                return "GH₵"
            case .hkd:
                return "HK$"
            case .ils:
                return "₪"
            case .inr:
                return "₹"
            case .jpy:
                return "JP¥"
            case .krw:
                return "₩"
            case .kzt:
                return "₸"
            case .mnt:
                return "₮"
            case .mxn:
                return "MX$"
            case .ngn:
                return "₦"
            case .nzd:
                return "NZ$"
            case .php:
                return "₱"
            case .pyg:
                return "₲"
            case .thb:
                return "฿"
            case .tryCurrency:
                return "₺"
            case .twd:
                return "NT$"
            case .uah:
                return "₴"
            case .vnd:
                return "₫"
            default:
                return self.code
            }
        }
    }

    struct FiatRate: Codable, Equatable, Sendable {
        public let unitsPerUsd: Double
        public let unitsPerGram: Double

        public init(unitsPerUsd: Double, unitsPerGram: Double) {
            self.unitsPerUsd = unitsPerUsd
            self.unitsPerGram = unitsPerGram
        }
    }

    struct FiatState: Equatable, Sendable {
        public let selectedCurrency: FiatCurrency
        public let rates: Resource<[FiatCurrency: FiatRate]>

        public init(selectedCurrency: FiatCurrency, rates: Resource<[FiatCurrency: FiatRate]>) {
            self.selectedCurrency = selectedCurrency
            self.rates = rates
        }

        public var selectedRate: FiatRate? {
            return self.rates.currentValue?[self.selectedCurrency]
        }
    }

    struct PreviousWallet: Equatable, Sendable, Identifiable {
        public let id: String
        public let address: String
        public let balance: Int64?
        public let lastUsedAt: Int32

        public init(id: String, address: String, balance: Int64?, lastUsedAt: Int32) {
            self.id = id
            self.address = address
            self.balance = balance
            self.lastUsedAt = lastUsedAt
        }
    }
    
    enum WalletAccountState: Equatable {
        case active
        case undeployed
        case unavailable
    }
    
    struct WalletInfo: Equatable, Sendable {
        public let address: String
        public let publicKey: String
        public let backupEnabled: Bool
        public let canExportPhrase: Bool
        public let canEnableBackup: Bool
        public let canSign: Bool

        public var canDisableBackup: Bool {
            return self.backupEnabled && self.canSign
        }

        public var canRevealPhrase: Bool {
            return self.canSign || self.canExportPhrase
        }

        public init(
            address: String,
            publicKey: String,
            backupEnabled: Bool = false,
            canExportPhrase: Bool = false,
            canEnableBackup: Bool = false,
            canSign: Bool = false
        ) {
            self.address = address
            self.publicKey = publicKey
            self.backupEnabled = backupEnabled
            self.canExportPhrase = canExportPhrase
            self.canEnableBackup = canEnableBackup
            self.canSign = canSign
        }
    }

    enum TonConnectPermission: Equatable, Sendable {
        case address
        case proof(String)
    }
    
    struct TonConnectRequest: Equatable, Sendable {
        public let id: String
        public let applicationName: String
        public let domain: String
        public let icon: WalletTonConnectIcon?
        public let permissions: [TonConnectPermission]
        public let requestsProof: Bool

        public init(
            id: String,
            applicationName: String,
            domain: String,
            icon: WalletTonConnectIcon?,
            permissions: [TonConnectPermission],
            requestsProof: Bool
        ) {
            self.id = id
            self.applicationName = applicationName
            self.domain = domain
            self.icon = icon
            self.permissions = permissions
            self.requestsProof = requestsProof
        }
    }

    struct TonConnectOperationRequest: Equatable, Sendable {
        public enum Method: Equatable, Sendable {
            case sendTransaction
            case signMessage
            case signData
        }

        public struct Message: Equatable, Sendable {
            public enum Payload: Equatable, Sendable {
                case empty
                case comment(String)
                case raw(String)
            }

            public let id: String
            public let destination: String
            public let amountNanograms: String
            public let payload: Payload
            public let stateInit: String?

            public init(
                id: String,
                destination: String,
                amountNanograms: String,
                payload: Payload,
                stateInit: String?
            ) {
                self.id = id
                self.destination = destination
                self.amountNanograms = amountNanograms
                self.payload = payload
                self.stateInit = stateInit
            }
        }

        public struct Action: Equatable, Sendable {
            public let id: String
            public let kind: String
            public let succeeded: Bool
            public let accounts: [String]
            public let detailsJson: String

            public init(id: String, kind: String, succeeded: Bool, accounts: [String], detailsJson: String = "{}") {
                self.id = id
                self.kind = kind
                self.succeeded = succeeded
                self.accounts = accounts
                self.detailsJson = detailsJson
            }
        }

        public let id: String
        public let applicationName: String
        public let domain: String
        public let icon: WalletTonConnectIcon?
        public let method: Method
        public let messages: [Message]
        public let feeNanograms: String?
        public let validUntil: UInt64?
        public let signData: TonConnectSignDataRequest?
        public let relayerWillSubmit: Bool
        public let needsWalletStateInit: Bool
        public let warnings: [String]
        public let actions: [Action]

        public init(
            id: String,
            applicationName: String,
            domain: String,
            icon: WalletTonConnectIcon?,
            method: Method,
            messages: [Message],
            feeNanograms: String?,
            validUntil: UInt64?,
            relayerWillSubmit: Bool,
            needsWalletStateInit: Bool,
            warnings: [String],
            actions: [Action],
            signData: TonConnectSignDataRequest? = nil
        ) {
            self.id = id
            self.applicationName = applicationName
            self.domain = domain
            self.icon = icon
            self.method = method
            self.messages = messages
            self.feeNanograms = feeNanograms
            self.validUntil = validUntil
            self.relayerWillSubmit = relayerWillSubmit
            self.needsWalletStateInit = needsWalletStateInit
            self.warnings = warnings
            self.actions = actions
            self.signData = signData
        }
    }

    struct TonConnectSignDataRequest: Equatable, Sendable {
        public let id: String
        public let applicationName: String
        public let domain: String
        public let icon: WalletTonConnectIcon?
        public let payload: TonConnectSignDataPayload.Content
        public let address: String
        public let network: String
    }

    typealias TonConnectSession = TonConnectSessionInfo
    typealias TonConnectDecisionResult = TonConnectDecision
    typealias TonConnectReturn = TonConnectReturnTarget

    struct TonConnectActiveRequest: Equatable, Sendable {
        public enum Content: Equatable, Sendable {
            case connect(TonConnectRequest)
            case operation(TonConnectOperationRequest)
            case signData(TonConnectSignDataRequest)
        }
        public let content: Content
        public let status: TonConnectRequestStatus
        public var id: String {
            switch self.content {
            case let .connect(value): return value.id
            case let .operation(value): return value.id
            case let .signData(value): return value.id
            }
        }
    }

    struct TonConnectState: Equatable, Sendable {
        public let sessions: [TonConnectSession]
        public let active: TonConnectActiveRequest?
        public let presentationEnabled: Bool
        public let diagnostic: TonConnectDiagnostic?
        static let empty = TonConnectState(sessions: [], active: nil, presentationEnabled: false, diagnostic: nil)
    }

    enum FatalStorageError: Error, Equatable, Sendable {
        case keychainStatus(Int32)
        case corrupted
        case unsupportedVersion
        case identityMismatch
    }

    enum SynchronizationError: Error, Equatable, Sendable {
        case unavailable
        case network
        case timeout
        case invalidData
        case engine
        case http(statusCode: Int)
    }

    enum Resource<Value: Equatable>: Equatable {
        case idle
        case loading(previous: Value?)
        case value(Value, updatedAt: Int32)
        case stale(previous: Value?, error: SynchronizationError, lastSuccessfulAt: Int32?)

        public var currentValue: Value? {
            switch self {
            case .idle:
                return nil
            case let .loading(value):
                return value
            case let .value(value, _):
                return value
            case let .stale(value, _, _):
                return value
            }
        }

        public var lastSuccessfulAt: Int32? {
            switch self {
            case .idle, .loading:
                return nil
            case let .value(_, value):
                return value
            case let .stale(_, _, value):
                return value
            }
        }
    }

    struct Transaction: Equatable, Sendable {
        public enum Kind: Int32, Codable, Equatable, Sendable {
            case transfer = 0
            case deployContract = 1
            case keyChange = 2
        }

        public enum Direction: Int32, Codable, Equatable, Sendable {
            case incoming = 0
            case outgoing = 1
            case unknown = 2
        }

        public enum Currency: Int32, Codable, Equatable, Sendable {
            case ton = 0
            case usdt = 1
        }

        public enum Status: Int32, Codable, Equatable, Sendable {
            case completed = 0
            case pending = 1
            case failed = 2
        }

        public enum Peer: Equatable, @unchecked Sendable {
            case user(EnginePeer, address: String, domain: String?)
            case address(String, domain: String?)
            case onramp(address: String, domain: String?, providerName: String)
            case unsupported

            public var address: String? {
                let value: String
                switch self {
                case let .user(_, address, _):
                    value = address
                case let .address(address, _), let .onramp(address, _, _):
                    value = address
                case .unsupported:
                    return nil
                }
                if !value.isEmpty {
                    return value
                }
                return nil
            }

            public var domain: String? {
                let value: String?
                switch self {
                case let .user(_, _, domain), let .address(_, domain), let .onramp(_, domain, _):
                    value = domain
                case .unsupported:
                    value = nil
                }
                guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                    return nil
                }
                return value
            }

            public var displayName: String? {
                switch self {
                case let .user(peer, _, _):
                    return peer.debugDisplayTitle
                case let .onramp(_, _, providerName):
                    return providerName
                case .address, .unsupported:
                    return nil
                }
            }
        }

        public struct CollectibleTransfer: Codable, Equatable, Sendable {
            public enum Kind: Int32, Codable, Equatable, Sendable {
                case gift = 0
                case username = 1
                case anonymousNumber = 2
                case other = 3
            }

            public let address: String
            public let name: String
            public let image: WalletNftFile?
            public let thumbnail: WalletNftFile?
            public let lottie: WalletNftFile?
            public let collectionName: String?
            public let collectionUrl: String?
            public let kind: Kind

            public init(
                address: String,
                name: String,
                image: WalletNftFile?,
                thumbnail: WalletNftFile? = nil,
                lottie: WalletNftFile? = nil,
                collectionName: String? = nil,
                collectionUrl: String? = nil,
                kind: Kind
            ) {
                self.address = address
                self.name = name
                self.image = image
                self.thumbnail = thumbnail
                self.lottie = lottie
                self.collectionName = collectionName
                self.collectionUrl = collectionUrl
                self.kind = kind
            }
        }

        public let id: String
        public let presentationId: String
        public let transactionHash: String?
        public let logicalTime: String
        public let timestamp: Int32
        public let kind: Kind
        public let direction: Direction
        public let amount: Int64
        public let fee: Int64
        public let gasless: Bool
        public let peer: Peer
        public let comment: String?
        public let commentEncrypted: Bool
        public let currency: Currency
        public let collectible: CollectibleTransfer?
        public let status: Status

        public init(
            id: String,
            presentationId: String? = nil,
            transactionHash: String? = nil,
            logicalTime: String,
            timestamp: Int32,
            direction: Direction,
            amount: Int64,
            fee: Int64,
            gasless: Bool = false,
            peer: Peer,
            comment: String?,
            commentEncrypted: Bool = false,
            currency: Currency = .ton,
            collectible: CollectibleTransfer? = nil,
            status: Status = .completed,
            kind: Kind = .transfer
        ) {
            self.id = id
            self.presentationId = presentationId ?? id
            self.transactionHash = transactionHash
            self.logicalTime = logicalTime
            self.timestamp = timestamp
            self.kind = kind
            self.direction = direction
            self.amount = amount
            self.fee = fee
            self.gasless = gasless
            self.peer = peer
            self.comment = comment
            self.commentEncrypted = commentEncrypted
            self.currency = currency
            self.collectible = collectible
            self.status = status
        }

        public func isSelfTransfer(walletAddress: String?) -> Bool {
            guard self.kind == .transfer, let recipient = self.peer.address else {
                return false
            }
            return WalletContext.isSelfTransfer(recipient: recipient, walletAddress: walletAddress)
        }

        public var isVisibleInWalletHistory: Bool {
            if self.status == .failed || self.kind == .deployContract || self.kind == .keyChange {
                return true
            }
            if self.collectible != nil {
                return self.direction != .unknown
            }
            switch self.direction {
            case .incoming:
                return self.currency == .usdt || self.amount >= 10_000_000
            case .outgoing:
                return true
            case .unknown:
                return false
            }
        }
    }

    struct TransactionsState: Equatable, Sendable {
        public let items: [Transaction]
        public let offset: Int
        public let canLoadMore: Bool
        public let isLoadingMore: Bool
        public let error: SynchronizationError?

        public init(
            items: [Transaction],
            offset: Int,
            canLoadMore: Bool,
            isLoadingMore: Bool,
            error: SynchronizationError?
        ) {
            self.items = items
            self.offset = offset
            self.canLoadMore = canLoadMore
            self.isLoadingMore = isLoadingMore
            self.error = error
        }
    }

    struct Collectible: Codable, Equatable, Sendable {
        public enum Kind: Int32, Codable, Equatable, Sendable {
            case gift = 0
            case username = 1
            case anonymousNumber = 2
            case other = 3
        }

        public let address: String
        public let name: String
        public let subtitle: String
        public let kind: Kind
        public let description: String?
        public let collectionName: String?
        public let collectionUrl: String?
        public let attributes: [String: String]
        public let giftSlug: String?
        public let nft: WalletNftItem?

        public var image: WalletNftFile? { self.nft?.image ?? self.nft?.imageSmall }
        public var thumbnail: WalletNftFile? { self.nft?.imageSmall ?? self.nft?.image }
        public var lottie: WalletNftFile? { self.nft?.lottie }

        public init(
            address: String,
            name: String,
            subtitle: String = "NFT",
            kind: Kind = .other,
            description: String? = nil,
            collectionName: String? = nil,
            collectionUrl: String? = nil,
            attributes: [String: String] = [:],
            giftSlug: String? = nil,
            nft: WalletNftItem? = nil
        ) {
            self.address = address
            self.name = name
            self.subtitle = subtitle
            self.kind = kind
            self.description = description
            self.collectionName = collectionName
            self.collectionUrl = collectionUrl
            self.attributes = attributes
            self.giftSlug = giftSlug
            self.nft = nft
        }
    }

    struct CollectiblesState: Equatable, Sendable {
        public struct PageId: Equatable, Sendable {
            public let offset: String
            public let generation: UInt64
        }

        public let items: [Collectible]
        public let nextOffset: String?
        public let generation: UInt64
        public let isRefreshing: Bool
        public let isLoadingMore: Bool
        public let error: SynchronizationError?

        public var canLoadMore: Bool { self.nextOffset != nil }
        public var nextPage: PageId? {
            return self.nextOffset.map { PageId(offset: $0, generation: self.generation) }
        }

        public init(
            items: [Collectible],
            nextOffset: String?,
            generation: UInt64 = 0,
            isRefreshing: Bool = false,
            isLoadingMore: Bool,
            error: SynchronizationError?
        ) {
            self.items = items
            self.nextOffset = nextOffset
            self.generation = generation
            self.isRefreshing = isRefreshing
            self.isLoadingMore = isLoadingMore
            self.error = error
        }

        public static var empty: CollectiblesState {
            return CollectiblesState(items: [], nextOffset: nil, isLoadingMore: false, error: nil)
        }
    }

    struct PendingTransferRegistration: Equatable, Sendable {
        public let id: String
        let walletAddress: String
        let walletPublicKey: String
        let sessionId: UUID
        let generation: UInt64
    }

    struct PendingTransfer: Codable, Equatable, Sendable {
        public struct StreamingData: Codable, Equatable, Sendable {
            public let normalBodyHash: String?
            public let gaslessBodyHash: String?
            public var traceId: String?
            public var chainTraceId: String?

            public init(normalBodyHash: String?, gaslessBodyHash: String?, traceId: String? = nil, chainTraceId: String? = nil) {
                self.normalBodyHash = normalBodyHash
                self.gaslessBodyHash = gaslessBodyHash
                self.traceId = traceId
                self.chainTraceId = chainTraceId
            }
        }

        public enum Status: Int32, Codable, Equatable, Sendable {
            case broadcasting = 0
            case pending = 1
            case submissionUnknown = 2
            case confirmed = 3
        }

        public let id: String
        public let recipient: String
        public let amount: Int64
        public let comment: String?
        public let commentEncrypted: Bool
        public let collectibleAddress: String?
        public let normalizedHash: String?
        public let sentTransfer: WalletSentTransfer?
        public let expectedGasless: Bool
        public let pendingMessage: WalletPendingTransferMessageReference?
        public var streamingData: StreamingData?

        public var gasless: Bool {
            return self.sentTransfer?.gasless ?? self.expectedGasless
        }

        public var streamingTraceId: String? {
            return self.streamingData?.traceId ?? (self.sentTransfer?.gasless == true ? nil : self.normalizedHash)
        }

        public let fee: Int64?
        public let transactionHash: String?
        public let transactionLt: String?
        public var uiExpiresAt: Int32?
        public let createdAt: Int32
        public let status: Status
        public let isPreparing: Bool

        public init(
            id: String,
            recipient: String,
            amount: Int64,
            comment: String?,
            commentEncrypted: Bool = false,
            collectibleAddress: String? = nil,
            normalizedHash: String? = nil,
            sentTransfer: WalletSentTransfer? = nil,
            expectedGasless: Bool = false,
            pendingMessage: WalletPendingTransferMessageReference? = nil,
            streamingData: StreamingData? = nil,
            fee: Int64? = nil,
            transactionHash: String? = nil,
            transactionLt: String? = nil,
            uiExpiresAt: Int32? = nil,
            createdAt: Int32,
            status: Status,
            isPreparing: Bool = false
        ) {
            self.id = id
            self.recipient = recipient
            self.amount = amount
            self.comment = comment
            self.commentEncrypted = commentEncrypted
            self.collectibleAddress = collectibleAddress
            self.normalizedHash = normalizedHash
            self.sentTransfer = sentTransfer
            self.expectedGasless = expectedGasless
            self.pendingMessage = pendingMessage
            self.streamingData = streamingData
            self.fee = fee
            self.transactionHash = transactionHash
            self.transactionLt = transactionLt
            self.uiExpiresAt = uiExpiresAt
            self.createdAt = createdAt
            self.status = status
            self.isPreparing = isPreparing
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                id: try container.decode(String.self, forKey: .id),
                recipient: try container.decode(String.self, forKey: .recipient),
                amount: try container.decode(Int64.self, forKey: .amount),
                comment: try container.decodeIfPresent(String.self, forKey: .comment),
                commentEncrypted: try container.decodeIfPresent(Bool.self, forKey: .commentEncrypted) ?? false,
                collectibleAddress: try container.decodeIfPresent(String.self, forKey: .collectibleAddress),
                normalizedHash: try container.decodeIfPresent(String.self, forKey: .normalizedHash),
                sentTransfer: try container.decodeIfPresent(WalletSentTransfer.self, forKey: .sentTransfer),
                expectedGasless: try container.decodeIfPresent(Bool.self, forKey: .expectedGasless) ?? false,
                pendingMessage: try container.decodeIfPresent(WalletPendingTransferMessageReference.self, forKey: .pendingMessage),
                streamingData: try container.decodeIfPresent(StreamingData.self, forKey: .streamingData),
                fee: try container.decodeIfPresent(Int64.self, forKey: .fee),
                transactionHash: try container.decodeIfPresent(String.self, forKey: .transactionHash),
                transactionLt: try container.decodeIfPresent(String.self, forKey: .transactionLt),
                uiExpiresAt: try container.decodeIfPresent(Int32.self, forKey: .uiExpiresAt),
                createdAt: try container.decode(Int32.self, forKey: .createdAt),
                status: try container.decode(Status.self, forKey: .status),
                isPreparing: try container.decodeIfPresent(Bool.self, forKey: .isPreparing) ?? false
            )
        }
    }

    struct PreparedBackupDisable: Equatable, Sendable {
        public enum KeyRotationPhase: Equatable, Sendable {
            case prepared
            case pending
            case confirmed
        }

        public let id: String
        public let walletAddress: String
        public let walletPublicKey: String
        public let words: [String]
        public struct Rotation: Equatable, Sendable {
            public let newPublicKey: Data
            public let signedBoc: String
            public let seqno: UInt32
            public let expiresAt: Int32
            public let networkFeeNanograms: Int64?
            let phase: KeyRotationPhase
        }

        public let rotation: Rotation?
        public var updateSecretPhrase: Bool { self.rotation != nil }
        public var networkFeeNanograms: Int64? { self.rotation?.networkFeeNanograms }

        public init(id: String, walletAddress: String, walletPublicKey: String, words: [String]) {
            self.id = id
            self.walletAddress = walletAddress
            self.walletPublicKey = walletPublicKey
            self.words = words
            self.rotation = nil
        }

        public init(
            id: String,
            walletAddress: String,
            walletPublicKey: String,
            words: [String],
            newPublicKey: Data,
            signedBoc: String,
            seqno: UInt32,
            expiresAt: Int32,
            networkFeeNanograms: Int64? = nil,
            keyRotationPhase: KeyRotationPhase = .prepared
        ) {
            self.id = id
            self.walletAddress = walletAddress
            self.walletPublicKey = walletPublicKey
            self.words = words
            self.rotation = Rotation(
                newPublicKey: newPublicKey, signedBoc: signedBoc, seqno: seqno,
                expiresAt: expiresAt, networkFeeNanograms: networkFeeNanograms, phase: keyRotationPhase
            )
        }
    }

    struct PreparedRecoveryPhraseImport: Equatable, Sendable {
        public enum Disposition: Equatable, Sendable {
            case currentWallet
            case replacement
        }

        public let disposition: Disposition
        let recordId: String
        let sourceAddress: String
        let sourcePublicKey: Data
        let candidateAddress: String
        let candidatePublicKey: Data
        let candidateSigningPublicKey: Data

        init(
            disposition: Disposition,
            recordId: String,
            sourceAddress: String,
            sourcePublicKey: Data,
            candidateAddress: String,
            candidatePublicKey: Data,
            candidateSigningPublicKey: Data
        ) {
            self.disposition = disposition
            self.recordId = recordId
            self.sourceAddress = sourceAddress
            self.sourcePublicKey = sourcePublicKey
            self.candidateAddress = candidateAddress
            self.candidatePublicKey = candidatePublicKey
            self.candidateSigningPublicKey = candidateSigningPublicKey
        }
    }

    enum TransferSubmissionStage: Equatable, Sendable {
        case waitingForPreviousTransfer
        case signing
        case submitted
    }

    enum ActiveOperation: Equatable, Sendable {
        case creating
        case importing
        case recoveringPhrase
        case preparingRecoveryPhraseImport
        case completingRecoveryPhraseImport
        case enablingBackup
        case preparingBackupDisable
        case disablingBackup
        case preparingTransfer
        case submittingTransfer
        case tonConnect
        case decryptingComment
        case loadingMoreTransactions
        case loadingMoreCollectibles
    }

    enum Phase: Equatable, Sendable {
        case restoring
        case creating
        case empty
        case wallet(WalletInfo)
        case failed(FatalStorageError)
    }

    struct State: Equatable, Sendable {
        public let phase: Phase
        public let walletAddress: String?
        public let balance: Resource<Int64>
        public let transactions: TransactionsState
        public let collectibles: CollectiblesState
        public let pendingTransfers: [PendingTransfer]
        public let activeOperation: ActiveOperation?
        public let fiat: FiatState
        public let gaslessInfo: Resource<WalletGaslessInfo>

        public init(
            phase: Phase,
            walletAddress: String? = nil,
            balance: Resource<Int64>,
            transactions: TransactionsState,
            collectibles: CollectiblesState = .empty,
            pendingTransfers: [PendingTransfer],
            activeOperation: ActiveOperation?,
            fiat: FiatState = .init(selectedCurrency: .usd, rates: .idle),
            gaslessInfo: Resource<WalletGaslessInfo> = .idle
        ) {
            self.phase = phase
            switch phase {
            case let .wallet(info):
                self.walletAddress = info.address
            case .restoring:
                self.walletAddress = walletAddress
            case .creating, .empty, .failed:
                self.walletAddress = nil
            }
            self.balance = balance
            self.transactions = transactions
            self.collectibles = collectibles
            self.pendingTransfers = pendingTransfers
            self.activeOperation = activeOperation
            self.fiat = fiat
            self.gaslessInfo = gaslessInfo
        }
    }

    enum WalletError: Error, Equatable, Sendable {
        case unavailable
        case noWallet
        case invalidMnemonic
        case invalidAddress
        case invalidAmount
        case operationInProgress
        case previewFailed
        case previewIncomplete
        case preparedTransferExpired
        case preparedTransferNotFound
        case walletKeyMismatch
        case recoveryPhraseOutdated
        case network
        case requestPassword
        case invalidPassword
        case twoStepAuthMissing
        case authorizationCancelled
        case passwordTooFresh(Int32)
        case sessionTooFresh(Int32)
        case backupDisabled
        case backupNotAvailable
        case replacementInvalid
        case publicKeyInvalid
        case proofInvalid
        case proofExpired
        case rotationNotFound
        case keyRotationFailed
        case backupDisableNeedsConfirmation(PreparedBackupDisable)
        case preparedBackupDisableExpired
        case commentTooLong
        case commentEncryptionRecipientUnavailable
        case commentEncryptionFailed
        case commentDecryptionFailed
        case tokenInvalid
        case tokenExpired
        case clientKeyInvalid
        case partUnavailable
        case invalidBackupData
        case insufficientBalance(required: Int64)
        case storage(FatalStorageError)
        case engine(String)
    }

    struct ResolvedTransferRecipient: Equatable, Sendable {
        public let address: String
        public let displayName: String?
        public let transferLink: String?

        public var transferInput: String {
            return self.transferLink ?? self.address
        }

        public init(address: String, displayName: String?, transferLink: String? = nil) {
            self.address = address
            self.displayName = displayName
            self.transferLink = transferLink
        }
    }

    struct PreparedTransfer: Equatable, Sendable {
        public let id: String
        public let recipient: String
        public let amount: Int64
        public let requestedAmount: Int64
        public let isSendAll: Bool
        public let comment: String?
        public let commentEncrypted: Bool
        public let collectible: Collectible?
        public let fee: Int64
        public let expiresAt: Int32

        public init(
            id: String,
            recipient: String,
            amount: Int64,
            requestedAmount: Int64? = nil,
            isSendAll: Bool = false,
            comment: String?,
            commentEncrypted: Bool = false,
            collectible: Collectible? = nil,
            fee: Int64,
            expiresAt: Int32
        ) {
            self.id = id
            self.recipient = recipient
            self.amount = amount
            self.requestedAmount = requestedAmount ?? amount
            self.isSendAll = isSendAll
            self.comment = comment
            self.commentEncrypted = commentEncrypted
            self.collectible = collectible
            self.fee = fee
            self.expiresAt = expiresAt
        }
    }
}

@available(macOS 10.15, *)
extension WalletContext.Resource: Sendable where Value: Sendable {
}

@available(macOS 10.15, *)
extension WalletContext.ActiveOperation {
    var defersServerWalletState: Bool {
        switch self {
        case .creating, .importing, .recoveringPhrase, .preparingRecoveryPhraseImport, .completingRecoveryPhraseImport, .enablingBackup, .disablingBackup:
            return true
        case .preparingBackupDisable,
             .preparingTransfer, .submittingTransfer, .tonConnect, .decryptingComment, .loadingMoreTransactions, .loadingMoreCollectibles:
            return false
        }
    }
}
