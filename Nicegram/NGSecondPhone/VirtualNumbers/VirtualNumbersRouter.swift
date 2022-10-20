protocol VirtualNumbersRouterInput: AnyObject {
    /// Test method
    func dismiss()
}

final class VirtualNumbersRouter: VirtualNumbersRouterInput {
    weak var parentViewController: VirtualNumbersViewController?

    func dismiss() {
        // Examples:

        // 1. Present view controller
        // parentViewController.present(someViewController, animated: true, completion: nil)

        // 2. Push view controller into the stack
        // parentViewController.navigationController?.pushViewController(someWhereViewController, animated: true)

        parentViewController?.dismiss(animated: false, completion: nil)
    }
}
