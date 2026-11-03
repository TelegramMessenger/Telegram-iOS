import Foundation
import CoreFoundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

@available(macOS 10.15, *)
private enum WalletEngineRelayError: Error {
    case completedWithoutResponse
    case invalidRequest
    case invalidResponse
    case responseTooLarge
}

private let maximumStatuslessResponseBytes = 4 * 1024 * 1024

@available(macOS 10.15, *)
func walletEngineTransportKind(_ code: URLError.Code) -> StatuslessHostErrorKind {
    switch code {
    case .notConnectedToInternet, .internationalRoamingOff, .dataNotAllowed, .callIsActive:
        return .offline
    case .timedOut:
        return .timeout
    case .networkConnectionLost, .cannotConnectToHost:
        return .connectionLost
    case .cancelled:
        return .cancelled
    default:
        return .other
    }
}

@available(macOS 10.15, *)
final class WalletSignalRequestContext<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var disposable: Disposable?
    private var result: Result<Value, Error>?
    private var started = false

    deinit {
        self.disposable?.dispose()
    }

    func run<SignalError: Error>(_ signal: Signal<Value, SignalError>) async throws -> Value {
        try Task.checkCancellation()
        self.start(signal)
        return try await self.value()
    }

    func cancel() {
        self.finish(.failure(CancellationError()))
    }

    func start<SignalError: Error>(_ signal: Signal<Value, SignalError>) {
        self.lock.lock()
        precondition(!self.started)
        self.started = true
        let alreadyFinished = self.result != nil
        self.lock.unlock()
        guard !alreadyFinished else { return }

        let disposable = signal.start(next: { [weak self] value in
            self?.finish(.success(value))
        }, error: { [weak self] error in
            self?.finish(.failure(error))
        }, completed: { [weak self] in
            self?.finish(.failure(WalletEngineRelayError.completedWithoutResponse))
        })

        self.lock.lock()
        let disposeImmediately = self.result != nil
        if !disposeImmediately {
            self.disposable = disposable
        }
        self.lock.unlock()
        if disposeImmediately {
            disposable.dispose()
        }
    }

    func value() async throws -> Value {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.lock.lock()
                if let result = self.result {
                    self.lock.unlock()
                    continuation.resume(with: result)
                } else {
                    precondition(self.continuation == nil)
                    self.continuation = continuation
                    self.lock.unlock()
                }
            }
        }, onCancel: {
            self.finish(.failure(CancellationError()))
        })
    }

    private func finish(_ result: Result<Value, Error>) {
        self.lock.lock()
        guard self.result == nil else {
            self.lock.unlock()
            return
        }
        self.result = result
        let continuation = self.continuation
        let disposable = self.disposable
        self.continuation = nil
        self.disposable = nil
        self.lock.unlock()

        disposable?.dispose()
        continuation?.resume(with: result)
    }
}

@available(macOS 10.15, *)
actor WalletEngineStatuslessHost: WalletStatuslessHost {
    private static let maximumEarlyCancellations = 256

    private let engine: TelegramEngine
    private let logger: WalletLogger
    private let requestCoalescer = WalletRequestCoalescer()
    private var tasks: [UInt64: Task<Data, Error>] = [:]
    private var cancelledBeforeStart = Set<UInt64>()

    init(engine: TelegramEngine, logger: WalletLogger) {
        self.engine = engine
        self.logger = logger
    }

    func executeStatusless(request: HttpRequest) async throws -> Data {
        let id = request.id.value
        guard self.tasks[id] == nil else {
            let error = Self.failure(.policyViolation, "Duplicate provider request identifier")
            self.logger.error("wallet_statusless_request_failed", error)
            throw error
        }
        guard self.cancelledBeforeStart.remove(id) == nil else {
            let error = Self.failure(.cancelled, "Provider request was cancelled")
            self.logger.error("wallet_statusless_request_failed", error)
            throw error
        }

        let engine = self.engine
        let requestCoalescer = self.requestCoalescer
        let task = Task<Data, Error> {
            try await Self.perform(request, engine: engine, requestCoalescer: requestCoalescer)
        }
        self.tasks[id] = task
        defer { self.tasks[id] = nil }

        do {
            return try await task.value
        } catch let error as CancellationError {
            self.logger.error("wallet_statusless_request_failed", error)
            throw Self.failure(.cancelled, "Provider request was cancelled")
        } catch let error as StatuslessHostError {
            self.logger.error("wallet_statusless_request_failed", error)
            throw error
        } catch let error as TonApiRequestError {
            self.logger.error("wallet_statusless_request_failed", error)
            throw Self.failure(.other, "Telegram relay failed (\(error.code))")
        } catch let error as URLError {
            self.logger.error("wallet_statusless_request_failed", error)
            throw Self.failure(walletEngineTransportKind(error.code), error.localizedDescription)
        } catch let error as WalletEngineRelayError {
            self.logger.error("wallet_statusless_request_failed", error)
            switch error {
            case .responseTooLarge:
                throw Self.failure(.responseTooLarge, "Provider response exceeds 4 MiB")
            case .invalidRequest:
                throw Self.failure(.policyViolation, "Provider request body is not valid UTF-8")
            case .invalidResponse:
                throw Self.failure(.other, "Provider response is invalid")
            case .completedWithoutResponse:
                throw Self.failure(.other, "Telegram relay completed without a response")
            }
        } catch {
            self.logger.error("wallet_statusless_request_failed", error)
            throw Self.failure(.other, String(describing: error))
        }
    }

    func cancelStatusless(requestId: HttpRequestId) async {
        if let task = self.tasks[requestId.value] {
            task.cancel()
        } else {
            self.cancelledBeforeStart.insert(requestId.value)
            while self.cancelledBeforeStart.count > Self.maximumEarlyCancellations,
                  let oldest = self.cancelledBeforeStart.min() {
                self.cancelledBeforeStart.remove(oldest)
            }
        }
    }

    func walletPublicKey(address: String) async throws -> Data {
        try Task.checkCancellation()
        guard !address.isEmpty else {
            throw WalletEngineRelayError.invalidRequest
        }
        let body = try JSONSerialization.data(withJSONObject: [
            "id": 1,
            "jsonrpc": "2.0",
            "method": "runGetMethod",
            "params": [
                "address": address,
                "method": "get_public_key",
                "stack": []
            ]
        ])
        guard let payload = String(data: body, encoding: .utf8) else {
            throw WalletEngineRelayError.invalidRequest
        }
        let engine = self.engine
        let response: String = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await WalletSignalRequestContext<String>().run(
                    engine.wallet.performPostRequest(endpoint: "/api/v2/jsonRPC", payload: payload)
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                throw Self.failure(.timeout, "Provider request timed out")
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else {
                throw Self.failure(.other, "Provider request produced no response")
            }
            return value
        }
        guard let publicKey = walletEnginePublicKey(fromToncenterResponse: Data(response.utf8)) else {
            throw WalletEngineRelayError.invalidResponse
        }
        return publicKey
    }

    func walletAccountState(address: String) async throws -> WalletContext.WalletAccountState {
        let data = try await self.walletAccountInformation(address: address)
        return try Self.walletAccountState(fromToncenterResponse: data)
    }

    static func walletAccountState(fromToncenterResponse data: Data) throws -> WalletContext.WalletAccountState {
        guard data.count <= maximumStatuslessResponseBytes,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["ok"] as? Bool == true, root["error"] == nil,
              let result = root["result"] as? [String: Any],
              let state = result["state"] as? String else {
            throw WalletContext.WalletError.network
        }
        switch state {
        case "active":
            return .active
        case "uninit", "uninitialized", "nonexist", "nonexistent":
            return .undeployed
        default:
            return .unavailable
        }
    }

    private func walletAccountInformation(address: String) async throws -> Data {
        try Task.checkCancellation()
        guard !address.isEmpty else { throw WalletEngineRelayError.invalidRequest }
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "address", value: address)]
        let query = components.percentEncodedQuery
        let engine = self.engine
        let response: String = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await WalletSignalRequestContext<String>().run(
                    engine.wallet.performGetRequest(endpoint: "/api/v2/getAddressInformation", query: query)
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                throw Self.failure(.timeout, "Provider request timed out")
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else {
                throw Self.failure(.other, "Provider request produced no response")
            }
            return value
        }
        let data = Data(response.utf8)
        guard data.count <= maximumStatuslessResponseBytes else {
            throw WalletEngineRelayError.responseTooLarge
        }
        return data
    }

    func walletBalance(address: String) async throws -> Int64 {
        let data = try await self.walletAccountInformation(address: address)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["ok"] as? Bool == true,
              let result = root["result"] as? [String: Any] else {
            throw WalletEngineRelayError.invalidResponse
        }
        let nanograms: String?
        if let value = result["balance"] as? String {
            nanograms = value
        } else if let value = result["balance"] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() {
            nanograms = value.stringValue
        } else {
            nanograms = nil
        }
        guard let nanograms, let balance = walletEngineBalance(nanograms) else {
            throw WalletEngineRelayError.invalidResponse
        }
        return balance
    }

    private static func perform(
        _ request: HttpRequest,
        engine: TelegramEngine,
        requestCoalescer: WalletRequestCoalescer
    ) async throws -> Data {
        guard let components = URLComponents(string: request.url),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.fragment == nil else {
            throw failure(.policyViolation, "Provider URL is invalid")
        }

        let endpoint = components.path.isEmpty ? "/" : components.path
        if case .get = request.method, endpoint == "/api/v2/getTransactions" {
            try Task.checkCancellation()
            // The app loads history through wallet.getTransactions; WalletEngine activity is unused.
            return Data(#"{"ok":true,"result":[]}"#.utf8)
        }
        if case .get = request.method, let key = WalletRequestCoalescingKey(
            isGet: true,
            url: request.url,
            headers: request.headers.map { WalletRequestCoalescingKey.Header(name: $0.name, value: $0.value) },
            body: request.body,
            timeoutMs: request.timeoutMs
        ) {
            return try await requestCoalescer.execute(key: key) {
                try await Self.performRelayRequest(request, endpoint: endpoint, query: components.percentEncodedQuery, engine: engine)
            }
        }
        return try await Self.performRelayRequest(request, endpoint: endpoint, query: components.percentEncodedQuery, engine: engine)
    }

    private static func performRelayRequest(
        _ request: HttpRequest,
        endpoint: String,
        query: String?,
        engine: TelegramEngine
    ) async throws -> Data {
        let response: String = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                switch request.method {
                case .get:
                    return try await WalletSignalRequestContext<String>().run(
                        engine.wallet.performGetRequest(endpoint: endpoint, query: query)
                    )
                case .post:
                    guard request.body.count <= maximumStatuslessResponseBytes else {
                        throw WalletEngineRelayError.responseTooLarge
                    }
                    let payload: String?
                    if request.body.isEmpty {
                        payload = nil
                    } else if let value = String(data: request.body, encoding: .utf8) {
                        payload = value
                    } else {
                        throw WalletEngineRelayError.invalidRequest
                    }
                    return try await WalletSignalRequestContext<String>().run(
                        engine.wallet.performPostRequest(endpoint: endpoint, payload: payload)
                    )
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: request.timeoutMs * 1_000_000)
                throw failure(.timeout, "Provider request timed out")
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else {
                throw failure(.other, "Provider request produced no response")
            }
            return value
        }

        let data = Data(response.utf8)
        guard data.count <= maximumStatuslessResponseBytes else {
            throw WalletEngineRelayError.responseTooLarge
        }
        return data
    }

    private static func failure(
        _ kind: StatuslessHostErrorKind,
        _ diagnostic: String
    ) -> StatuslessHostError {
        .Failed(kind: kind, diagnostic: sanitizedWalletEngineDiagnostic(diagnostic))
    }
}

@available(macOS 10.15, *)
func walletEnginePublicKey(fromToncenterResponse data: Data) -> Data? {
    guard data.count <= maximumStatuslessResponseBytes,
          let object = try? JSONSerialization.jsonObject(with: data),
          let root = object as? [String: Any],
          root["error"] == nil,
          root["ok"] as? Bool != false,
          let result = root["result"] as? [String: Any],
          let exitCode = result["exit_code"] as? NSNumber,
          CFGetTypeID(exitCode) != CFBooleanGetTypeID(),
          exitCode == 0 || exitCode == 1,
          let stack = result["stack"] as? [Any],
          let first = stack.first,
          let encoded = walletEngineStackNumber(first) else {
        return nil
    }
    return walletEngineUInt256(encoded)
}

@available(macOS 10.15, *)
private func walletEngineStackNumber(_ value: Any) -> String? {
    if let values = value as? [Any], values.count == 2,
       values[0] as? String == "num" {
        return values[1] as? String
    }
    if let value = value as? [String: Any], value["type"] as? String == "num" {
        return value["value"] as? String
    }
    return nil
}

@available(macOS 10.15, *)
private func walletEngineUInt256(_ value: String) -> Data? {
    var bytes = [UInt8](repeating: 0, count: 32)
    if value.hasPrefix("0x") || value.hasPrefix("0X") {
        let digits = value.dropFirst(2)
        guard !digits.isEmpty, digits.count <= 64 else {
            return nil
        }
        var nibbleIndex = 64 - digits.count
        for character in digits {
            guard let nibble = character.hexDigitValue else {
                return nil
            }
            let byteIndex = nibbleIndex / 2
            if nibbleIndex.isMultiple(of: 2) {
                bytes[byteIndex] = UInt8(nibble << 4)
            } else {
                bytes[byteIndex] |= UInt8(nibble)
            }
            nibbleIndex += 1
        }
    } else {
        guard !value.isEmpty else {
            return nil
        }
        for character in value {
            guard let digit = character.wholeNumberValue, digit < 10 else {
                return nil
            }
            var carry = digit
            for index in bytes.indices.reversed() {
                let accumulated = Int(bytes[index]) * 10 + carry
                bytes[index] = UInt8(accumulated & 0xff)
                carry = accumulated >> 8
            }
            guard carry == 0 else {
                return nil
            }
        }
    }
    guard bytes.contains(where: { $0 != 0 }) else {
        return nil
    }
    return Data(bytes)
}
