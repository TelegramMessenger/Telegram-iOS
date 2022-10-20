protocol ForgotPasswordRouterInput: AnyObject {
    /// Test method
    func dismiss()
}

final class ForgotPasswordRouter: ForgotPasswordRouterInput {
    weak var parentViewController: ForgotPasswordViewController?

    func dismiss() {
        parentViewController?.navigationController?.popViewController(animated: true)
    }
}
