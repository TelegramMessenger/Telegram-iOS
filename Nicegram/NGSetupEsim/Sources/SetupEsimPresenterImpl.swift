import UIKit
import NGLocalization

protocol SetupEsimPresenterInput { }

protocol SetupEsimPresenterOutput: AnyObject {
    func displayHeader(title: String, buttonImage: UIImage?)
    
    func display(videoTitle: String)
    
    func displayInstallStep(item: EsimSetupStepViewModel)
    func display(lpaItem: DescriptionItemViewModel)
    func display(activationCodeItem: DescriptionItemViewModel)
    
    func displayApnStep(item: EsimSetupStepViewModel)
    func display(apnItem: DescriptionItemViewModel)
    
    func displayRoamingStep(item: EsimSetupStepViewModel)
    func display(roamingItem: DescriptionItemViewModel)
    
    func display(buttonTitle: String)
    
    func copy(text: String)
}

final class SetupEsimPresenter: SetupEsimPresenterInput {
    
    //  MARK: - VIP
    
    weak var output: SetupEsimPresenterOutput!
    
    //  MARK: - Lifecycle
    
    init() {}
}

//  MARK: - Output

extension SetupEsimPresenter: SetupEsimInteractorOutput {
    func viewDidLoad() {
        output.displayHeader(title: ngLocalized("Nicegram.Install.Title"), buttonImage: UIImage(named: "ng.question.message"))
        output.display(videoTitle: ngLocalized("Nicegram.Install.VideoInstructions.Title"))
        output.display(buttonTitle: ngLocalized("Nicegram.Install.Done"))
    }
    
    func present(lpa: String, activationCode: String, apn: String) {
        output.displayInstallStep(item: EsimSetupStepViewModel(
            title: ngLocalized("Nicegram.Install.Manual.Title"),
            subtitle: ngLocalized("Nicegram.Install.Manual.Subtitle"),
            buttonTitle: ngLocalized("Nicegram.Install.Manual.Scan").uppercased(),
            buttonImage: UIImage(named: "ng.qr"))
        )
        
        output.display(lpaItem: DescriptionItemViewModel(
            title: ngLocalized("Nicegram.Install.Manual.Address"),
            subtitle: lpa,
            buttonImage: UIImage(named: "ng.copy"),
            showSwitch: false)
        )
        output.display(activationCodeItem: DescriptionItemViewModel(
            title: ngLocalized("Nicegram.Install.Manual.Code"),
            subtitle: activationCode,
            buttonImage: UIImage(named: "ng.copy"),
            showSwitch: false)
        )
        
        output.displayApnStep(item: EsimSetupStepViewModel(
            title: ngLocalized("Nicegram.Install.APN.Title"),
            subtitle: ngLocalized("Nicegram.Install.APN.Subtitle"),
            buttonTitle: nil,
            buttonImage: nil)
        )
        
        output.display(apnItem: DescriptionItemViewModel(
            title: ngLocalized("Nicegram.Install.APN"),
            subtitle: apn,
            buttonImage: UIImage(named: "ng.copy"),
            showSwitch: false)
        )
        
        output.displayRoamingStep(item: EsimSetupStepViewModel(
            title: ngLocalized("Nicegram.Install.Roaming.Title"),
            subtitle: ngLocalized("Nicegram.Install.Roaming.Subtitle"),
            buttonTitle: nil,
            buttonImage: nil)
        )
        
        output.display(roamingItem: DescriptionItemViewModel(
            title: ngLocalized("Nicegram.Install.Roaming.Data"),
            subtitle: nil,
            buttonImage: nil,
            showSwitch: true))
    }
    
    func copy(text: String) {
        output.copy(text: text)
    }
}
