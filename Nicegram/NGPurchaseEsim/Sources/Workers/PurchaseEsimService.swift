import UIKit
import NGLocalization
import NGModels

enum PurchaseEsimError: Error {
    case notAuthorized
    case cancelled
    case underlying(Error)
}

extension PurchaseEsimError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return ""
        case .cancelled:
            return ""
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}


protocol PurchaseEsimService {
    func topUpEsim(icc: String, offer: EsimOffer, from: UIViewController,  completion: ((Result<UserEsim, PurchaseEsimError>) -> ())?)
    func purchaseEsim(offer: EsimOffer, from: UIViewController, completion: ((Result<UserEsim, PurchaseEsimError>) -> ())?)
}

class PurchaseEsimServiceMock: PurchaseEsimService {
    func topUpEsim(icc: String, offer: EsimOffer, from: UIViewController, completion: ((Result<UserEsim, PurchaseEsimError>) -> ())?) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) {
//            let esim = UserEsim(icc: icc, lpa: "test_lpa", code: "test_code", regionId: offer.regionId, regionIsoCode: "Worldwide", phoneNumber: "+375298514766", balance: .money(offer.price), expirationDate: .unlimited, canTopUp: true)
//            completion?(.success(esim))
            
            completion?(.failure(.underlying(MessageError.unknown)))
        }
    }
    
    func purchaseEsim(offer: EsimOffer, from: UIViewController, completion: ((Result<UserEsim, PurchaseEsimError>) -> ())?) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) {
            let esim = UserEsim(icc: UUID().uuidString, lpa: "test_lpa", code: "test_code", regionId: offer.regionId, regionIsoCode: "Worldwide", phoneNumber: "+375298514766", balance: .money(offer.price), expirationDate: .unlimited, state: .active)
            completion?(.success(esim))
        }
    }
}
