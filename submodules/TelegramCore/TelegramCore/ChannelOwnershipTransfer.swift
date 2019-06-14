import Foundation
#if os(macOS)
import SwiftSignalKitMac
import PostboxMac
#else
import SwiftSignalKit
import Postbox
#endif

public enum ChannelOwnershipTransferError {
    case generic
    case twoStepAuthMissing
    case twoStepAuthTooFresh(Int32)
    case authSessionTooFresh(Int32)
    case requestPassword
    case invalidPassword
    case adminsTooMuch
    case userPublicChannelsTooMuch
    case restricted
    case userBlocked
}

public func checkOwnershipTranfserAvailability(postbox: Postbox, network: Network, accountStateManager: AccountStateManager, memberId: PeerId) -> Signal<Never, ChannelOwnershipTransferError> {
    return postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(memberId)
        }
    |> introduceError(ChannelOwnershipTransferError.self)
    |> mapToSignal { user -> Signal<Never, ChannelOwnershipTransferError> in
        guard let user = user else {
            return .fail(.generic)
        }
        guard let apiUser = apiInputUser(user) else {
            return .fail(.generic)
        }
        
        return network.request(Api.functions.channels.editCreator(channel: .inputChannelEmpty, userId: apiUser, password: .inputCheckPasswordEmpty))
        |> mapError { error -> ChannelOwnershipTransferError in
            if error.errorDescription == "PASSWORD_HASH_INVALID" {
                return .requestPassword
            } else if error.errorDescription == "PASSWORD_MISSING" {
                return .twoStepAuthMissing
            } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
                let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
                if let value = Int32(timeout) {
                    return .twoStepAuthTooFresh(value)
                }
            } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
                let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
                if let value = Int32(timeout) {
                    return .authSessionTooFresh(value)
                }
            } else if error.errorDescription == "CHANNELS_ADMIN_PUBLIC_TOO_MUCH" {
                return .userPublicChannelsTooMuch
            } else if error.errorDescription == "ADMINS_TOO_MUCH" {
                return .adminsTooMuch
            } else if error.errorDescription == "USER_PRIVACY_RESTRICTED" {
                return .restricted
            } else if error.errorDescription == "USER_BLOCKED" {
                return .userBlocked
            }
            return .generic
        }
        |> mapToSignal { updates -> Signal<Never, ChannelOwnershipTransferError> in
            accountStateManager.addUpdates(updates)
            return.complete()
        }
    }
}

public func updateChannelOwnership(postbox: Postbox, network: Network, accountStateManager: AccountStateManager, channelId: PeerId, memberId: PeerId, password: String) -> Signal<Never, ChannelOwnershipTransferError> {
    guard !password.isEmpty else {
        return .fail(.invalidPassword)
    }
    
    return postbox.transaction { transaction -> (channel: Peer?, user: Peer?) in
        return (channel: transaction.getPeer(channelId), user: transaction.getPeer(memberId))
    }
    |> introduceError(ChannelOwnershipTransferError.self)
    |> mapToSignal { channel, user -> Signal<Never, ChannelOwnershipTransferError> in
        guard let channel = channel, let user = user else {
            return .fail(.generic)
        }
        guard let apiChannel = apiInputChannel(channel) else {
            return .fail(.generic)
        }
        guard let apiUser = apiInputUser(user) else {
            return .fail(.generic)
        }
        
        let checkPassword = twoStepAuthData(network)
        |> mapError { _ in ChannelOwnershipTransferError.generic }
        |> mapToSignal { authData -> Signal<Api.InputCheckPasswordSRP, ChannelOwnershipTransferError> in
            if let currentPasswordDerivation = authData.currentPasswordDerivation, let srpSessionData = authData.srpSessionData {
                guard let kdfResult = passwordKDF(password: password, derivation: currentPasswordDerivation, srpSessionData: srpSessionData) else {
                    return .fail(.generic)
                }
                return .single(.inputCheckPasswordSRP(srpId: kdfResult.id, A: Buffer(data: kdfResult.A), M1: Buffer(data: kdfResult.M1)))
            } else {
                return .fail(.twoStepAuthMissing)
            }
        }
        
        return checkPassword
        |> mapToSignal { password -> Signal<Never, ChannelOwnershipTransferError> in
            return network.request(Api.functions.channels.editCreator(channel: apiChannel, userId: apiUser, password: password))
            |> mapError { error -> ChannelOwnershipTransferError in
                if error.errorDescription == "PASSWORD_HASH_INVALID" {
                    return .invalidPassword
                } else if error.errorDescription == "PASSWORD_MISSING" {
                    return .twoStepAuthMissing
                } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
                    let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
                    if let value = Int32(timeout) {
                        return .twoStepAuthTooFresh(value)
                    }
                } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
                    let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
                    if let value = Int32(timeout) {
                        return .authSessionTooFresh(value)
                    }
                } else if error.errorDescription == "CHANNELS_ADMIN_PUBLIC_TOO_MUCH" {
                    return .userPublicChannelsTooMuch
                } else if error.errorDescription == "ADMINS_TOO_MUCH" {
                    return .adminsTooMuch
                } else if error.errorDescription == "USER_PRIVACY_RESTRICTED" {
                    return .restricted
                } else if error.errorDescription == "USER_BLOCKED" {
                    return .userBlocked
                }
                return .generic
            }
            |> mapToSignal { updates -> Signal<Never, ChannelOwnershipTransferError> in
                accountStateManager.addUpdates(updates)
                return.complete()
            }
        }
    }
}
