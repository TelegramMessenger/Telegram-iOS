import UIKit
import NGCustomViews
import NGLocalization
import NGModels
import NGPhoneFormatter
import NGRegionsFormatter
import NGMoneyFormatter

protocol MyEsimsPresenterInput { }

protocol MyEsimsPresenterOutput: AnyObject {
    func displayHeader(title: String, buttonImage: UIImage)
    func display(sectionTitle: String)
    func display(items: [MyEsimViewModel])
    func display(isLoading: Bool)
    func display(isRefreshing: Bool)
    func displayEmptyState(message: String, buttonTitle: String)
    func displayErrorModal(message: String)
    func displayErrorToast(message: String)
    func displayFetchErrorAsPlaceholder(message: String)
    func hidePlaceholder()
    func copy(text: String)
}

final class MyEsimsPresenter: MyEsimsPresenterInput {
    
    //  MARK: - VIP
    
    weak var output: MyEsimsPresenterOutput!
    
    //  MARK: - Logic
    
    private var currentItems: [UserEsim] = []
    
    //  MARK: - Dependencies
    
    private let phoneFormatter: PhoneFormatter
    private let regionsFormatter: RegionsFormatter
    private let moneyFormatter: MoneyFormatter
    
    //  MARK: - Lifecycle
    
    init(phoneFormatter: PhoneFormatter, regionsFormatter: RegionsFormatter, moneyFormatter: MoneyFormatter) {
        self.phoneFormatter = phoneFormatter
        self.regionsFormatter = regionsFormatter
        self.moneyFormatter = moneyFormatter
    }
}

//  MARK: - Output

extension MyEsimsPresenter: MyEsimsInteractorOutput {
    func viewDidLoad() {
        setupView()
    }
    
    func present(cachedEsims esims: [UserEsim]) {
        self.currentItems = esims
        output.display(items: mapEsimsToViewModels(esims))
        output.hidePlaceholder()
    }
    
    func present(esims: [UserEsim]) {
        self.currentItems = esims
        output.display(items: mapEsimsToViewModels(esims))
        
        if esims.isEmpty {
            displayEmptyState()
        } else {
            output.hidePlaceholder()
        }
    }
    
    func present(fetchError: FetchUserEsimsError) {
        switch fetchError {
        case .notAuthorized:
            displayEmptyState()
        case .underlying(let error):
            if currentItems.isEmpty {
                output.displayFetchErrorAsPlaceholder(message: error.localizedDescription)
            } else {
                output.displayErrorToast(message: error.localizedDescription)
            }
        }
    }
    
    func present(refreshError: Error) {
        output.displayErrorToast(message: refreshError.localizedDescription)
    }
    
    func presentBlockedEsimTopUpError() {
        output.displayErrorModal(message: ngLocalized("Error.EsimProfileBlocked"))
    }
    
    func presentExpiredEsimTopUpError() {
        output.displayErrorModal(message: ngLocalized("Error.EsimProfileExpired"))
    }
    
    func present(isLoading: Bool) {
        if !currentItems.isEmpty && isLoading {
            return
        }
        output.display(isLoading: isLoading)
    }
    
    func present(isRefreshing: Bool) {
        output.display(isRefreshing: isRefreshing)
    }
    
    func copy(phoneNumber: String) {
        let formattedPhoneNumber = phoneFormatter.format(phoneNumber: phoneNumber, to: .international) ?? phoneNumber
        output.copy(text: formattedPhoneNumber)
    }
}

//  MARK: - Mapping

private extension MyEsimsPresenter {
    func mapEsimsToViewModels(_ esims: [UserEsim]) -> [MyEsimViewModel] {
        return esims.map({ self.mapEsimToViewModel($0) })
    }
    
    func mapEsimToViewModel(_ esim: UserEsim) -> MyEsimViewModel {
        let subtitle: String?
        let subtitleButtonImage: UIImage?
        if let phoneNumber = esim.phoneNumber {
            subtitle = phoneFormatter.format(phoneNumber: phoneNumber, to: .international)
            subtitleButtonImage = UIImage(named: "ng.copy")
        } else {
            subtitle = nil
            subtitleButtonImage = nil
        }
        
        let headerItem = HeaderCardViewModel(
            title: localizedRegionName(esim: esim),
            subtitle: subtitle,
            subtitleButtonImage: subtitleButtonImage,
            backgroundImage: UIImage(named: "ng.worldwide.background")!)
        
        let balance: String
        let unit: String?
        switch esim.balance {
        case .money(let money):
            balance = moneyFormatter.format(money)
            unit = nil
        case .megabytes(let megabytes):
            balance = "\(megabytes)"
            unit = ngLocalized("Nicegram.MobileData.MyEsim.Mb")
        }
        
        let duration: String
        switch esim.expirationDate {
        case .notActivated:
            duration = "Not activated"
        case .unlimited:
            duration = ngLocalized("Nicegram.MobileData.MyEsim.Duration.Status")
        case .date(let date):
            duration = formatDate(date)
        }
        
        return MyEsimViewModel(
            id: esim.id,
            headerItem: headerItem,
            balanceCaption: ngLocalized("Nicegram.MobileData.MyEsim.Status").uppercased(),
            balance: balance,
            unit: unit,
            durationCaption: ngLocalized("Nicegram.MobileData.MyEsim.Duration").uppercased(),
            duration: duration.uppercased(),
            topUpButtonTitle: ngLocalized("Nicegram.MobileData.MyEsim.Add").uppercased(),
            topUpButtonImage: UIImage(named: "ng.plus")!,
            faqButtonTitle: ngLocalized("Nicegram.MobileData.MyEsim.FAQ"))
    }
    
    func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        return dateFormatter.string(from: date)
    }
    
    func localizedRegionName(esim: UserEsim) -> String {
        return regionsFormatter.localizedRegionName(isoCode: esim.regionIsoCode)
    }
}

//  MARK: - Private Functions

private extension MyEsimsPresenter {
    func setupView() {
        output.displayHeader(
            title: ngLocalized("Nicegram.MobileData.Title"),
            buttonImage: UIImage(named: "ng.plus")!
        )
        output.display(sectionTitle: ngLocalized("Nicegram.MobileData.MyEsim.Title"))
    }
    
    func displayEmptyState() {
        output.displayEmptyState(message: ngLocalized("Nicegram.MobileData.NoData"), buttonTitle: ngLocalized("Nicegram.MobileData.Action.Add"))
    }
}
