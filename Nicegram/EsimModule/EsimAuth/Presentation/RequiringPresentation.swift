import UIKit

public protocol RequiringPresentation {
    var presentationDelegate: RequiringPresentationDelegate? { get set }
}

public protocol RequiringPresentationDelegate: AnyObject {
    func presentingViewController() -> UIViewController
}
