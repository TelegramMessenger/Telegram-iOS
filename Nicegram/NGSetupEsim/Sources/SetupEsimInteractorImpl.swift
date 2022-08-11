import Foundation
import NGLocalization
import NGModels

typealias SetupEsimInteractorInput = SetupEsimViewControllerOutput

protocol SetupEsimInteractorOutput {
    func viewDidLoad()
    func present(lpa: String, activationCode: String, apn: String)
    func copy(text: String)
}

final class SetupEsimInteractor {
    
    //  MARK: - VIP
    
    var output: SetupEsimInteractorOutput!
    var router: SetupEsimRouter!
    
    //  MARK: - Logic
    
    private let activationInfo: EsimActivationInfo
    private let apn = "internet"
    
    //  MARK: - Lifecycle
    
    init(activationInfo: EsimActivationInfo) {
        self.activationInfo = activationInfo
    }
    
}

//  MARK: - Output

extension SetupEsimInteractor: SetupEsimInteractorInput {
    func viewDidLoad() {
        output.viewDidLoad()
        output.present(lpa: activationInfo.lpa, activationCode: activationInfo.code, apn: apn)
    }
    
    func supportTapped() {
        router.routeToSupport()
    }
    
    func playVideoTapped() {
        guard let url = videoTutorialUrl() else { return }
        router.routeToVideo(url: url)
    }
    
    func scanQrTapped() {
        router.routeToScanQR(string: esimActivationQRString(lpa: activationInfo.lpa, code: activationInfo.code))
    }
    
    func lpaTapped() {
        output.copy(text: activationInfo.lpa)
    }
    
    func activationCodeTapped() {
        output.copy(text: activationInfo.code)
    }
    
    func apnTapped() {
        output.copy(text: apn)
    }
    
    func dataRoamingTapped() {
        router.routeToAppSettings()
    }
    
    func doneTapped() {
        router.dismiss()
    }
}

private extension SetupEsimInteractor {
    func esimActivationQRString(lpa: String, code: String) -> String {
        return "LPA:1$\(lpa)$\(code)"
    }
    
    func videoTutorialUrl() -> URL? {
        let defaultUrl = "https://youtube.com/shorts/eZ9WgKWPOUA"
        
        let url: String
        switch Locale.currentAppLocale.languageCode {
        case "ar": url = "https://youtube.com/shorts/C_8LM9OnC80"
        case "de": url = "https://youtube.com/shorts/3U7EEXjvT_E"
        case "en": url = "https://youtube.com/shorts/eZ9WgKWPOUA"
        case "es": url = "https://youtube.com/shorts/8LdilGYoaZk"
        case "fr": url = "https://youtube.com/shorts/dAn6JTlZihk"
        case "it": url = "https://youtube.com/shorts/ExBH6MUg2TI"
        case "ko": url = "https://youtube.com/shorts/wUYqcD0kUSc"
        case "pt": url = "https://youtube.com/shorts/ermMaMaNYzA"
        case "ru": url = "https://youtube.com/shorts/Ve6CnHqYMnI"
        case "tr": url = "https://youtube.com/shorts/FKT5lTblBZs"
        case "zh", "zh-hans", "zh-hant": url = defaultUrl
        default: url = defaultUrl
            
        }
        return URL(string: url)
    }
}
