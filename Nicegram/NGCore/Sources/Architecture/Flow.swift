import UIKit

public protocol Flow: AnyObject {
    associatedtype Input
    associatedtype Handlers
    func makeStartViewController(input: Input, handlers: Handlers) -> UIViewController
}
