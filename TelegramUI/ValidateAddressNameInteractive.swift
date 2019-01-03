import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox

enum AddressNameValidationStatus: Equatable {
    case checking
    case invalidFormat(AddressNameFormatError)
    case availability(AddressNameAvailability)
    
    static func ==(lhs: AddressNameValidationStatus, rhs: AddressNameValidationStatus) -> Bool {
        switch lhs {
            case .checking:
                if case .checking = rhs {
                    return true
                } else {
                    return false
                }
            case let .invalidFormat(error):
                if case .invalidFormat(error) = rhs {
                    return true
                } else {
                    return false
                }
            case let .availability(availability):
                if case .availability(availability) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

func validateAddressNameInteractive(account: Account, domain: AddressNameDomain, name: String) -> Signal<AddressNameValidationStatus, NoError> {
    if let error = checkAddressNameFormat(name) {
        return .single(.invalidFormat(error))
    } else {
        return .single(.checking) |> then(addressNameAvailability(account: account, domain: domain, name: name)
        |> delay(0.3, queue: Queue.concurrentDefaultQueue())
        |> map { result -> AddressNameValidationStatus in .availability(result) })
    }
}
