protocol CountriesListRouterInput: AnyObject {
    func dismiss()
}

final class CountriesListRouter: CountriesListRouterInput {
    weak var parentViewController: CountriesListViewController?

    func dismiss() {
        parentViewController?.dismiss(animated: true, completion: nil)
    }
}
