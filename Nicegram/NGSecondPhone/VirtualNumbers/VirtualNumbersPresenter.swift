import NGCustomViews

protocol VirtualNumbersPresenterInput {
    //
}

protocol VirtualNumbersPresenterOutput: AnyObject {
    func display(numbers: [MyNumberItem])
}

final class VirtualNumbersPresenter: VirtualNumbersPresenterInput {
    weak var output: VirtualNumbersPresenterOutput!

//    func presentSomething(response: CreateOrderResponse) {
//        // NOTE: Format the response from the Interactor and pass the result back to the View Controller
//
//        let viewModel = SomeViewModel()
//        output.displaySmth(viewModel)
//    }
}

extension VirtualNumbersPresenter: VirtualNumbersInteractorOutput {
    func onViewDidLoad() {
        let numberItems = [
            MyNumberItem(
                title: "Local Number",
                phoneNumber: "+1 (555) 123-9928",
                exparationType: .active,
                date: "25.07.2021"
            ),
            MyNumberItem(
                title: "Mobile",
                phoneNumber: "+1 (555) 123-9928",
                exparationType: .expires,
                date: "25.07.2021"
            ),
            MyNumberItem(
                title: "Mobile",
                phoneNumber: "+1 (555) 123-9928",
                exparationType: .unactive,
                date: "25.07.2021"
            )
        ]
        output.display(numbers: numberItems)
    }
}
