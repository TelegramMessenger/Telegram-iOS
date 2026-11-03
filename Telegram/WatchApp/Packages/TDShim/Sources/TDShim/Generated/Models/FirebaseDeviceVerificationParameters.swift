//
//  FirebaseDeviceVerificationParameters.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes parameters to be used for device verification
public indirect enum FirebaseDeviceVerificationParameters: Codable, Equatable, Hashable {

    /// Device verification must be performed with the SafetyNet Attestation API
    case firebaseDeviceVerificationParametersSafetyNet(FirebaseDeviceVerificationParametersSafetyNet)

    /// Device verification must be performed with the classic Play Integrity verification (https://developer.android.com/google/play/integrity/classic)
    case firebaseDeviceVerificationParametersPlayIntegrity(FirebaseDeviceVerificationParametersPlayIntegrity)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case firebaseDeviceVerificationParametersSafetyNet
        case firebaseDeviceVerificationParametersPlayIntegrity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .firebaseDeviceVerificationParametersSafetyNet:
            let value = try FirebaseDeviceVerificationParametersSafetyNet(from: decoder)
            self = .firebaseDeviceVerificationParametersSafetyNet(value)
        case .firebaseDeviceVerificationParametersPlayIntegrity:
            let value = try FirebaseDeviceVerificationParametersPlayIntegrity(from: decoder)
            self = .firebaseDeviceVerificationParametersPlayIntegrity(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .firebaseDeviceVerificationParametersSafetyNet(let value):
            try container.encode(Kind.firebaseDeviceVerificationParametersSafetyNet, forKey: .type)
            try value.encode(to: encoder)
        case .firebaseDeviceVerificationParametersPlayIntegrity(let value):
            try container.encode(Kind.firebaseDeviceVerificationParametersPlayIntegrity, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// Device verification must be performed with the SafetyNet Attestation API
public struct FirebaseDeviceVerificationParametersSafetyNet: Codable, Equatable, Hashable {

    /// Nonce to pass to the SafetyNet Attestation API
    public let nonce: Data


    public init(nonce: Data) {
        self.nonce = nonce
    }
}

/// Device verification must be performed with the classic Play Integrity verification (https://developer.android.com/google/play/integrity/classic)
public struct FirebaseDeviceVerificationParametersPlayIntegrity: Codable, Equatable, Hashable {

    /// Cloud project number to pass to the Play Integrity API
    public let cloudProjectNumber: TdInt64

    /// Base64url-encoded nonce to pass to the Play Integrity API
    public let nonce: String


    public init(
        cloudProjectNumber: TdInt64,
        nonce: String
    ) {
        self.cloudProjectNumber = cloudProjectNumber
        self.nonce = nonce
    }
}

