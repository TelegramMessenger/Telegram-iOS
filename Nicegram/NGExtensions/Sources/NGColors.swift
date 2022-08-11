import UIKit

extension UIColor {
    open class var ngRedAlert: UIColor {
        return UIColor(red: 0.922, green: 0.333, blue: 0.271, alpha: 1)
    }

    open class var ngPurple: UIColor {
        return UIColor(red: 0.631, green: 0.204, blue: 0.78, alpha: 1)
    }

    open class var ngGrey: UIColor {
        return UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
    }

    open class var ngYellow: UIColor {
        return UIColor(red: 0.984, green: 0.737, blue: 0.02, alpha: 1)
    }

    open class var ngDarkOrange: UIColor {
        return UIColor(red: 0.804, green: 0.471, blue: 0, alpha: 1)
    }

    open class var ngLightOrange: UIColor {
        return UIColor(red: 1, green: 0.584, blue: 0, alpha: 1)
    }

    open class var ngRedOne: UIColor {
        return UIColor(red: 0.776, green: 0.047, blue: 0.047, alpha: 1)
    }

    open class var ngRedTwo: UIColor {
        return UIColor(red: 1, green: 0.231, blue: 0.188, alpha: 1)
    }

    open  class var ngRedThree: UIColor {
        return UIColor(red: 0.922, green: 0.333, blue: 0.271, alpha: 1)
    }

    open class var ngRedFour: UIColor {
        return UIColor(red: 1, green: 0, blue: 0, alpha: 1)
    }

    open  class var ngRedFive: UIColor {
        return UIColor(red: 1, green: 0.22, blue: 0.141, alpha: 1)
    }

    open class var ngBlueOne: UIColor {
        return UIColor(red: 0.039, green: 0.518, blue: 1, alpha: 1)
    }

    open class var ngBlueTwo: UIColor {
        return UIColor(red: 0, green: 0.64, blue: 1, alpha: 1)
    }

    open class var ngBlueThree: UIColor {
        return UIColor(red: 0.208, green: 0.667, blue: 0.859, alpha: 1)
    }

    open class var ngBlueFour: UIColor {
        return UIColor(red: 0.039, green: 0.769, blue: 1, alpha: 1)
    }

    open class var ngBlueFive: UIColor {
        return UIColor(red: 0, green: 0.9, blue: 0.846, alpha: 1)
    }

    open class var ngGreenOne: UIColor {
        return UIColor(red: 0.157, green: 0.718, blue: 0.447, alpha: 1)
    }

    open class var ngGreenTwo: UIColor {
        return UIColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1)
    }

    open class var ngGreenThree: UIColor {
        return UIColor(red: 0.031, green: 0.655, blue: 0.137, alpha: 1)
    }

    open class var ngSubtitle: UIColor {
        return UIColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1)
    }

    open class var ngBodyTwo: UIColor {
        return UIColor(red: 0.678, green: 0.678, blue: 0.682, alpha: 1)
    }

    open class var ngBodyThree: UIColor {
        return UIColor(red: 0.333, green: 0.333, blue: 0.345, alpha: 1)
    }

    open class var ngBackground: UIColor {
        return UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1)
    }

    open class var ngPopupBackground: UIColor {
        return UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1)
    }

    open class var ngCardBackground: UIColor {
        return UIColor(red: 0.153, green: 0.153, blue: 0.161, alpha: 1)
    }

    open class var ngDarkGrey: UIColor {
        return UIColor(red: 0.251, green: 0.251, blue: 0.267, alpha: 1)
    }

    open class var ngLine: UIColor {
        return UIColor(red: 0.333, green: 0.333, blue: 0.345, alpha: 1)
    }

    open class var ngActiveButton: UIColor {
        return UIColor(red: 0, green: 0.64, blue: 1, alpha: 1)
    }

    open class var ngInactiveButton: UIColor {
        return UIColor(red: 0.2, green: 0.2, blue: 0.204, alpha: 1)
    }

    open class var ngRedButton: UIColor {
        return UIColor(red: 0.922, green: 0.333, blue: 0.271, alpha: 1)
    }
    
    // MARK: White theme
    
    open class var ngWhiteBackground: UIColor {
        return UIColor(red: 0.937, green: 0.937, blue: 0.957, alpha: 1)
    }
    
    open class var ngWhiteIncativeButton: UIColor {
        return UIColor(red: 0.678, green: 0.678, blue: 0.682, alpha: 1)
    }
}

public extension Array where Element == UIColor {
    static let defaultGradient: [UIColor] = [
        UIColor(red: 0.744, green: 0.332, blue: 0.928, alpha: 1),
        UIColor(red: 0.306, green: 0.675, blue: 0.954, alpha: 1)
    ]
}
