typealias HintInteractorInput = HintViewControllerOutput

protocol HintInteractorOutput {
    func handleViewDidLoad()
}

class HintInteractor: HintInteractorInput {
    var output: HintInteractorOutput! 
    
    func handleViewDidLoad() {
        output.handleViewDidLoad()
    }
}
