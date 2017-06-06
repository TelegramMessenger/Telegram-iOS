import Foundation

enum PluralizationForm {
    case zero
    case one
    case two
    case few
    case many
    case other
    
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

func presentationStringsPluralizationForm(_ lc: UInt32, _ value: Int32) -> PluralizationForm {
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
    }
}
