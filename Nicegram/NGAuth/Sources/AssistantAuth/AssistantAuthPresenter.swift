import UIKit
import NGLocalization

protocol AssistantAuthPresenterInput {
    // func presentSmth(response: SomeResponse)
}

protocol AssistantAuthPresenterOutput: AnyObject {
    func displayLoginWithEmail(title: String?, image: UIImage?)
    func displayLoginWithGoogle(title: String?, image: UIImage?)
    func displayLoginWithApple(title: String?, image: UIImage?)
}

final class AssistantAuthPresenter: AssistantAuthPresenterInput {
    weak var output: AssistantAuthPresenterOutput!

//    func presentSomething(response: CreateOrderResponse) {
//        // NOTE: Format the response from the Interactor and pass the result back to the View Controller
//
//        let viewModel = SomeViewModel()
//        output.displaySmth(viewModel)
//    }
}

extension AssistantAuthPresenter: AssistantAuthInteractorOutput { 
    func onViewDidLoad() {
        let emailTitle = "Log in with Email"
        let emailImage = UIImage(named: "NGEmailIcon")
        output.displayLoginWithEmail(title: emailTitle, image: emailImage)

        let googleTitle = ngLocalized("Auth.SignInWithGoogle")
        let googleImage = UIImage(named: "NGGoogleIcon")
        output.displayLoginWithGoogle(title: googleTitle, image: googleImage)

        let appleTitle = "Log in with Apple"
        let appleImage = UIImage(named: "NGAppleIcon")
        output.displayLoginWithApple(title: appleTitle, image: appleImage)
    }
}
