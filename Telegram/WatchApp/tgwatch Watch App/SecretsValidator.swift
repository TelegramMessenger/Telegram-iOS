import Foundation

enum ConfigError: Equatable, Swift.Error {
    case missingApiId
    case missingApiHash
    case placeholderApiHash

    var humanMessage: String {
        switch self {
        case .missingApiId, .missingApiHash, .placeholderApiHash:
            return "Missing API credentials. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig and fill in your values."
        }
    }
}

func validateSecrets(apiId: Int, apiHash: String) -> Result<Void, ConfigError> {
    if apiId <= 0 { return .failure(.missingApiId) }
    let trimmed = apiHash.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return .failure(.missingApiHash) }
    if trimmed == "replace_with_32_hex_chars" { return .failure(.placeholderApiHash) }
    return .success(())
}
