import Foundation
import TDLibKit
import TDLibFramework

// MARK: - Argument parsing

func printUsage() -> Never {
    fputs("Usage: test-helper delete-account --api-id <id> --api-hash <hash> --phone <number>\n", stderr)
    exit(1)
}

func parseArgs() -> (apiId: Int, apiHash: String, phone: String) {
    let args = CommandLine.arguments
    guard args.count >= 2, args[1] == "delete-account" else { printUsage() }

    var apiId: Int?
    var apiHash: String?
    var phone: String?

    var i = 2
    while i < args.count {
        switch args[i] {
        case "--api-id":
            i += 1; guard i < args.count, let v = Int(args[i]) else { printUsage() }
            apiId = v
        case "--api-hash":
            i += 1; guard i < args.count else { printUsage() }
            apiHash = args[i]
        case "--phone":
            i += 1; guard i < args.count else { printUsage() }
            phone = args[i]
        default:
            printUsage()
        }
        i += 1
    }

    guard let apiId, let apiHash, let phone else { printUsage() }
    return (apiId, apiHash, phone)
}

// MARK: - Phone number validation

/// Parses a test phone number (format: 99966XYYYY or +99966XYYYY).
/// Returns (fullNumber with + prefix, verification code).
func parseTestPhone(_ phone: String) -> (fullNumber: String, code: String)? {
    let digits = phone.hasPrefix("+") ? String(phone.dropFirst()) : phone
    guard digits.count == 10, digits.hasPrefix("99966") else { return nil }
    let dcDigit = digits[digits.index(digits.startIndex, offsetBy: 5)]
    guard dcDigit >= "1", dcDigit <= "3" else { return nil }
    let code = String(repeating: dcDigit, count: 5)
    let fullNumber = "+\(digits)"
    return (fullNumber, code)
}

// MARK: - TDLib account deletion

func deleteTestAccount(apiId: Int, apiHash: String, phone: String, code: String) async throws {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-helper-\(ProcessInfo.processInfo.processIdentifier)")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    // Suppress TDLib's verbose C++ logging
    td_execute("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}")

    let manager = TDLibClientManager()
    defer { manager.closeClients() }

    let authState = AsyncStream.makeStream(of: AuthorizationState.self)

    let client = manager.createClient { data, client in
        guard let update = try? client.decoder.decode(Update.self, from: data) else { return }
        if case .updateAuthorizationState(let s) = update {
            authState.continuation.yield(s.authorizationState)
        }
    }

    for await state in authState.stream {
        switch state {
        case .authorizationStateWaitTdlibParameters:
            try await client.setTdlibParameters(
                apiHash: apiHash,
                apiId: apiId,
                applicationVersion: "1.0",
                databaseDirectory: tmpDir.path,
                databaseEncryptionKey: Data(),
                deviceModel: "test-helper",
                filesDirectory: tmpDir.appendingPathComponent("files").path,
                systemLanguageCode: "en",
                systemVersion: "macOS",
                useChatInfoDatabase: false,
                useFileDatabase: false,
                useMessageDatabase: false,
                useSecretChats: false,
                useTestDc: true
            )

        case .authorizationStateWaitPhoneNumber:
            try await client.setAuthenticationPhoneNumber(
                phoneNumber: phone,
                settings: PhoneNumberAuthenticationSettings?.none
            )

        case .authorizationStateWaitCode:
            try await client.checkAuthenticationCode(code: code)

        case .authorizationStateWaitRegistration:
            print("No account for \(phone) (sign-up requested). Nothing to delete.")
            authState.continuation.finish()
            return

        case .authorizationStateReady:
            print("Logged in. Deleting account...")
            try await client.deleteAccount(password: String?.none, reason: "test cleanup")
            print("Account deleted.")
            authState.continuation.finish()
            return

        case .authorizationStateClosed:
            authState.continuation.finish()
            return

        default:
            fputs("Unexpected auth state: \(state)\n", stderr)
            authState.continuation.finish()
            throw NSError(domain: "test-helper", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unexpected auth state"
            ])
        }
    }
}

// MARK: - Main

let (apiId, apiHash, phone) = parseArgs()

guard let parsed = parseTestPhone(phone) else {
    fputs("Error: phone must match format 99966XYYYY (X = 1, 2, or 3)\n", stderr)
    exit(1)
}

do {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await deleteTestAccount(apiId: apiId, apiHash: apiHash, phone: parsed.fullNumber, code: parsed.code)
        }
        group.addTask {
            try await Task.sleep(for: .seconds(30))
            throw NSError(domain: "test-helper", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Timed out after 30 seconds"
            ])
        }
        try await group.next()
        group.cancelAll()
    }
} catch let error as TDLibKit.Error {
    fputs("Error: [\(error.code)] \(error.message)\n", stderr)
    exit(1)
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}

exit(0)
