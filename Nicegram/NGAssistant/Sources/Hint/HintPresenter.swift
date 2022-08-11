import NGLocalization

typealias HintPresenterInput = HintInteractorOutput

protocol HintPresenterOutput: AnyObject {
    func display(titleText: String?,
                 subtitleText: String?,
                 mobileDataText: String?,
                 virtualNumberText: String?,
                 walletText: String?,
                 supportText: String?,
                 footerText: String?)
}

final class HintPresenter: HintPresenterInput {
    weak var output: HintPresenterOutput!
    
    func handleViewDidLoad() {
        output.display(
            titleText: ngLocalized("Nicegram.Assistant.Hint.Title"),
            subtitleText:  ngLocalized("Nicegram.Assistant.Hint.Subtitle"), 
            mobileDataText: ngLocalized("Nicegram.Assistant.Hint.MobileData"), 
            virtualNumberText: ngLocalized("Nicegram.Assistant.Hint.VirtualNumber"),
            walletText: ngLocalized("Nicegram.Assistant.Hint.Wallet"), 
            supportText: ngLocalized("Nicegram.Assistant.Hint.Support"),
            footerText: ngLocalized("Nicegram.Assistant.Hint.Footer")
        )
    }
}
