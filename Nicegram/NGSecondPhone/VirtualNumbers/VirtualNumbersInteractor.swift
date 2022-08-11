typealias VirtualNumbersInteractorInput = VirtualNumbersViewControllerOutput

protocol VirtualNumbersInteractorOutput {
    func onViewDidLoad()
}

final class VirtualNumbersInteractor {
    var output: VirtualNumbersInteractorOutput!
}

extension VirtualNumbersInteractor: VirtualNumbersInteractorInput {
    func onViewDidLoad() {
        output.onViewDidLoad()
    }
}
