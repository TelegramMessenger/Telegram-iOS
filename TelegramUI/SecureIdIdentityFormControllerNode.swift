import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

final class SecureIdIdentityFormState: FormControllerInnerState {
    func isEqual(to: SecureIdIdentityFormState) -> Bool {
        return false
    }
    
    func entries() -> [FormControllerItemEntry<SecureIdIdentityFormEntry>] {
        return [.entry(SecureIdIdentityFormEntry.scansHeader)]
    }
}

enum SecureIdIdentityFormEntryId: Hashable {
    case scansHeader
    case scan(Int)
    
    static func ==(lhs: SecureIdIdentityFormEntryId, rhs: SecureIdIdentityFormEntryId) -> Bool {
        switch lhs {
            case .scansHeader:
                if case .scansHeader = rhs {
                    return true
                } else {
                    return false
                }
            case let .scan(index):
                if case .scan(index) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case .scansHeader:
                return 0
            case let .scan(index):
                return index.hashValue
        }
    }
}

enum SecureIdIdentityFormEntry: FormControllerEntry {
    case scansHeader
    
    var stableId: SecureIdIdentityFormEntryId {
        switch self {
            case .scansHeader:
                return .scansHeader
        }
    }
    
    func isEqual(to: SecureIdIdentityFormEntry) -> Bool {
        switch self {
            case .scansHeader:
                if case .scansHeader = to {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func item(strings: PresentationStrings) -> FormControllerItem {
        switch self {
            case .scansHeader:
                return FormControllerHeaderItem(text: "SCANS")
        }
    }
}

final class SecureIdIdentityFormControllerNode: FormControllerNode<SecureIdIdentityFormState> {
    required init(theme: PresentationTheme, strings: PresentationStrings) {
        super.init(theme: theme, strings: strings)
        
        self.updateInnerState(transition: .immediate, with: SecureIdIdentityFormState())
    }
    
    func verify() {
        
    }
}

