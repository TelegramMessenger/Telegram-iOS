protocol RegistrationRouterInput: AnyObject {
    /// Test method
    func dismiss()
}

final class RegistrationRouter: RegistrationRouterInput {
    weak var parentViewController: RegistrationViewController?

    func dismiss() {
        parentViewController?.navigationController?.popViewController(animated: true)
    }
}
