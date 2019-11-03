import Foundation
import Postbox
import SwiftSignalKit

public enum AddressNameValidationStatus: Equatable {
    case checking
    case invalidFormat(AddressNameFormatError)
    case availability(AddressNameAvailability)
}

public func validateAddressNameInteractive(account: Account, domain: AddressNameDomain, name: String) -> Signal<AddressNameValidationStatus, NoError> {
    if let error = checkAddressNameFormat(name) {
        return .single(.invalidFormat(error))
    } else {
        return .single(.checking)
        |> then(
            addressNameAvailability(account: account, domain: domain, name: name)
            |> delay(0.3, queue: Queue.concurrentDefaultQueue())
            |> map { result -> AddressNameValidationStatus in
                .availability(result)
            }
        )
    }
}
