import CoreFoundation
import Foundation

enum WebProxyPageStatus: String, CaseIterable, Equatable {
    case connecting
    case reconnecting
    case connected
    case failed
}

enum WebProxyControlMessage: Equatable {
    case initialize(nonce: String)
    case status(WebProxyPageStatus)
    case traffic(up: UInt64, down: UInt64)
    case close

    static func decode(_ value: String) throws -> WebProxyControlMessage {
        guard value.utf8.count <= 4096,
              let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let type = dictionary["t"] as? String else {
            throw WebProxyControlMessageError.invalidMessage
        }

        switch type {
        case "tproxy-android-init":
            guard Self.hasExactKeys(dictionary, ["nonce", "t", "v"]),
                  Self.integer(dictionary["v"]) == 1,
                  let nonce = dictionary["nonce"] as? String,
                  Self.isCanonicalNonce(nonce) else {
                throw WebProxyControlMessageError.invalidInitialization
            }
            return .initialize(nonce: nonce)
        case "status":
            guard Self.hasExactKeys(dictionary, ["state", "t"]),
                  let rawStatus = dictionary["state"] as? String,
                  let status = WebProxyPageStatus(rawValue: rawStatus) else {
                throw WebProxyControlMessageError.invalidMessage
            }
            return .status(status)
        case "traffic":
            guard Self.hasExactKeys(dictionary, ["down", "t", "up"]),
                  let up = Self.trafficCount(dictionary["up"]),
                  let down = Self.trafficCount(dictionary["down"]) else {
                throw WebProxyControlMessageError.invalidMessage
            }
            return .traffic(up: up, down: down)
        case "close":
            guard Self.hasExactKeys(dictionary, ["t"]) else {
                throw WebProxyControlMessageError.invalidMessage
            }
            return .close
        default:
            throw WebProxyControlMessageError.invalidMessage
        }
    }

    private static func hasExactKeys(_ dictionary: [String: Any], _ keys: Set<String>) -> Bool {
        return Set(dictionary.keys) == keys
    }

    private static func integer(_ value: Any?) -> UInt64? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        let doubleValue = number.doubleValue
        guard doubleValue.isFinite,
              doubleValue >= 0.0,
              doubleValue.rounded(.towardZero) == doubleValue,
              doubleValue <= Double(UInt64.max) else {
            return nil
        }
        return number.uint64Value
    }

    private static func trafficCount(_ value: Any?) -> UInt64? {
        guard let value = Self.integer(value),
              value <= UInt64(WebProxyProtocol.maximumQueuedBytes) else {
            return nil
        }
        return value
    }

    private static func isCanonicalNonce(_ value: String) -> Bool {
        guard value.utf8.count == 43 else { return false }
        return value.utf8.allSatisfy { byte in
            return (byte >= 48 && byte <= 57)
                || (byte >= 65 && byte <= 90)
                || (byte >= 97 && byte <= 122)
                || byte == 45
                || byte == 95
        }
    }
}

enum WebProxyControlMessageError: Error, Equatable {
    case invalidMessage
    case invalidInitialization
}
