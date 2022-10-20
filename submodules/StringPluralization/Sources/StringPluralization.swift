import Foundation
import NumberPluralizationForm

public enum PluralizationForm: Int32 {
    case zero = 0
    case one = 1
    case two = 2
    case few = 3
    case many = 4
    case other = 5
    
    var name: String {
        switch self {
            case .zero:
                return "zero"
            case .one:
                return "one"
            case .two:
                return "two"
            case .few:
                return "few"
            case .many:
                return "many"
            case .other:
                return "other"
        }
    }
}

public func getPluralizationForm(_ lc: UInt32, _ value: Int32) -> PluralizationForm {
    switch numberPluralizationForm(lc, value) {
        case .zero:
            return .zero
        case .one:
            return .one
        case .two:
            return .two
        case .few:
            return .few
        case .many:
            return .many
        case .other:
            return .other
        @unknown default:
            fatalError()
    }
}
