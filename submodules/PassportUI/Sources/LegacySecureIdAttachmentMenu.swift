import Foundation
import UIKit
import LegacyComponents
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import OverlayStatusController
import AccountContext
import LegacyUI
import ImageCompression
import PresentationDataUtils

enum SecureIdAttachmentMenuType {
    case generic
    case idCard
    case multiple
    case selfie
}

struct SecureIdRecognizedDocumentData {
    let documentType: String?
    let documentSubtype: String?
    let issuingCountry: String?
    let nationality: String?
    let lastName: String?
    let firstName: String?
    let documentNumber: String?
    let birthDate: Date?
    let gender: String?
    let expiryDate: Date?
}

func presentLegacySecureIdAttachmentMenu(context: AccountContext, present: @escaping (ViewController) -> Void, validLayout: ContainerViewLayout, type: SecureIdAttachmentMenuType, recognizeDocumentData: Bool, completion: @escaping ([TelegramMediaResource], SecureIdRecognizedDocumentData?) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: validLayout)
    legacyController.statusBar.statusBarStyle = .Ignore
    
    let emptyController = LegacyEmptyController(context: legacyController.context)!
    let navigationController = makeLegacyNavigationController(rootController: emptyController)
    navigationController.setNavigationBarHidden(true, animated: false)
    navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
    legacyController.bind(controller: navigationController)
    
    present(legacyController)
    
    let mappedIntent: TGPassportAttachIntent
    switch type {
        case .generic:
            mappedIntent = TGPassportAttachIntentDefault
        case .idCard:
            mappedIntent = TGPassportAttachIntentIdentityCard
        case .multiple:
            mappedIntent = TGPassportAttachIntentMultiple
        case .selfie:
            mappedIntent = TGPassportAttachIntentSelfie
    }
    
    var uploadStarted = false
    
    guard let attachMenu = TGPassportAttachMenu.present(with: legacyController.context, parentController: emptyController, menuController: nil, title: "", intent: mappedIntent, uploadAction: { signal, completed in
        if let signal = signal {
            if uploadStarted {
                completed?()
                return
            }
            uploadStarted = true
            let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            let statusDisposable = (Signal<Never, NoError> { subscriber in
                present(statusController)
                return ActionDisposable {
                    statusController.dismiss()
                }
            }
            |> runOn(.mainQueue())
            |> delay(0.1, queue: .mainQueue())).start()
            
            let _ = (processedLegacySecureIdAttachmentItems(postbox: context.account.postbox, signal: signal)
            |> mapToSignal { resources -> Signal<([TelegramMediaResource], SecureIdRecognizedDocumentData?), NoError> in
                switch type {
                    case .generic, .idCard:
                        if recognizeDocumentData {
                            return recognizedResources(postbox: context.account.postbox, resources: resources, shouldBeDriversLicense: false)
                                |> map { data -> ([TelegramMediaResource], SecureIdRecognizedDocumentData?) in
                                    return (resources, data)
                            }
                        }
                    default:
                        break
                }
                return .single((resources, nil))
            }
            |> deliverOnMainQueue).start(next: { resourcesAndData in
                completion(resourcesAndData.0, resourcesAndData.1)
                statusDisposable.dispose()
                completed?()
            })
        } else {
            completed?()
        }
    }, sourceView: nil, sourceRect: nil, barButtonItem: nil) else {
        legacyController.dismiss()
        return
    }
    attachMenu.didDismiss = { [weak legacyController] _ in
        legacyController?.dismiss()
    }
    attachMenu.customRemoveFromParentViewController = { [weak legacyController] in
        legacyController?.dismiss()
    }
}

private enum AttachmentItem {
    case image(UIImage)
    case iCloud(URL)
}

private func processedLegacySecureIdAttachmentItems(postbox: Postbox, signal: SSignal) -> Signal<[TelegramMediaResource], NoError> {
    let nativeSignal = Signal<AttachmentItem?, NoError> { subscriber in
        let disposable = signal.start(next: { next in
            if let dict = next as? [String: Any], let image = dict["image"] as? UIImage {
                subscriber.putNext(.image(image))
            } else if let next = next as? URL {
                subscriber.putNext(.iCloud(next))
            }
        }, error: nil, completed: {
            subscriber.putCompletion()
        })
        return ActionDisposable {
            disposable?.dispose()
        }
    }
    let collectedSignal = nativeSignal
    |> mapToSignal { value -> Signal<UIImage?, NoError> in
        guard let value = value else {
            return .single(nil)
        }
        switch value {
            case let .image(image):
                return .single(image)
            case let .iCloud(url):
                return Signal<UIImage?, NoError> { subscriber in
                    let disposable = TGPassportICloud.fetchFile(with: url).start(next: { next in
                        if let url = next as? URL {
                            subscriber.putNext(UIImage(contentsOfFile: url.path))
                        }
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    return ActionDisposable {
                        disposable?.dispose()
                    }
                }
        }
    }
    |> map { image -> [TelegramMediaResource] in
        guard let image = image else {
            return []
        }
        let randomId = Int64.random(in: Int64.min ... Int64.max)
        let tempFilePath = NSTemporaryDirectory() + "\(randomId).jpeg"
        let scaledSize = image.size.aspectFitted(CGSize(width: 2048.0, height: 2048.0))
        if let scaledImage = TGScaleImageToPixelSize(image, scaledSize), let scaledImageData = compressImageToJPEG(scaledImage, quality: 0.84) {
            let _ = try? scaledImageData.write(to: URL(fileURLWithPath: tempFilePath))
            let resource = LocalFileReferenceMediaResource(localFilePath: tempFilePath, randomId: randomId)
            return [resource]
        } else {
            return []
        }
    }

    let collectedItems: Signal<[TelegramMediaResource], NoError> = collectedSignal
    |> reduceLeft(value: [] as [TelegramMediaResource], f: { (list: [TelegramMediaResource], rest: [TelegramMediaResource]) -> [TelegramMediaResource] in
        var list = list
        list.append(contentsOf: rest)
        return list
    })
    return collectedItems
}

private func recognizedResources(postbox: Postbox, resources: [TelegramMediaResource], shouldBeDriversLicense: Bool) -> Signal<SecureIdRecognizedDocumentData?, NoError> {
    var signals: [Signal<SecureIdRecognizedDocumentData?, NoError>] = []
    for resource in resources {
        let image = Signal<UIImage?, NoError> { subscriber in
            let fetch = postbox.mediaBox.fetchedResource(resource, parameters: nil).start()
            let data = (postbox.mediaBox.resourceData(resource)
            |> map { data -> UIImage? in
                if data.complete {
                    return UIImage(contentsOfFile: data.path)
                }
                return nil
            }).start(next: { next in
                subscriber.putNext(next)
            }, completed: {
                subscriber.putCompletion()
            })
            return ActionDisposable {
                fetch.dispose()
                data.dispose()
            }
        }
        |> last
        let recognized = image
        |> mapToSignal { image -> Signal<SecureIdRecognizedDocumentData?, NoError> in
            if let image = image {
                return Signal { subscriber in
                    let disposable = TGPassportOCR.recognizeData(in: image, shouldBeDriversLicense: shouldBeDriversLicense)?.start(next: { value in
                        if let value = value as? TGPassportMRZ {
                            var issuingCountry: String? = nil
                            if let issuingCountryValue = value.issuingCountry {
                                issuingCountry = countryCodeAlpha3ToAlpha2(issuingCountryValue)
                            }
                            var nationality: String? = nil
                            if let nationalityValue = value.nationality {
                                nationality = countryCodeAlpha3ToAlpha2(nationalityValue)
                            }
                            subscriber.putNext(SecureIdRecognizedDocumentData(documentType: value.documentType, documentSubtype: value.documentSubtype, issuingCountry: issuingCountry, nationality: nationality, lastName: value.lastName.capitalized, firstName: value.firstName.capitalized, documentNumber: value.documentNumber, birthDate: value.birthDate, gender: value.gender, expiryDate: value.expiryDate))
                            subscriber.putCompletion()
                        } else {
                            subscriber.putNext(nil)
                            subscriber.putCompletion()
                        }
                    }, completed: nil)
                    
                    return ActionDisposable {
                        disposable?.dispose()
                    }
                }
            } else {
                return .single(nil)
            }
        }
        signals.append(recognized)
    }
    return combineLatest(signals)
    |> map { values -> SecureIdRecognizedDocumentData? in
        for value in values {
            if let value = value {
                return value
            }
        }
        return nil
    }
}

private struct IsoCountryInfo {
    var name: String
    var numeric: String
    var alpha2: String
    var alpha3: String
    var calling: String
    var currency: String
    var continent: String
}

func countryCodeAlpha3ToAlpha2(_ code: String) -> String? {
    for country in IsoCountries.allCountries {
        if country.alpha3 == code {
            return country.alpha2
        }
    }
    return nil
}

private class IsoCountries {
    class var allCountries: Array<IsoCountryInfo> {
        get {
            return [
                IsoCountryInfo(name: "Afghanistan", numeric: "004", alpha2: "AF", alpha3: "AFG", calling: "+93", currency: "AFN", continent: "AS" ),
                IsoCountryInfo(name: "Åland Islands", numeric: "248", alpha2: "AX", alpha3: "ALA", calling: "+358", currency: "FIM", continent: "EU" ),
                IsoCountryInfo(name: "Albania", numeric: "008", alpha2: "AL", alpha3: "ALB", calling: "+355", currency: "ALL", continent: "EU" ),
                IsoCountryInfo(name: "Algeria", numeric: "012", alpha2: "DZ", alpha3: "DZA", calling: "+213", currency: "DZD", continent: "AF" ),
                IsoCountryInfo(name: "American Samoa", numeric: "016", alpha2: "AS", alpha3: "ASM", calling: "+684", currency: "USD", continent: "OC" ),
                IsoCountryInfo(name: "Andorra", numeric: "020", alpha2: "AD", alpha3: "AND", calling: "+376", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Angola", numeric: "024", alpha2: "AO", alpha3: "AGO", calling: "+244", currency: "AOA", continent: "AF" ),
                IsoCountryInfo(name: "Anguilla", numeric: "660", alpha2: "AI", alpha3: "AIA", calling: "+264", currency: "XCD", continent: "NA" ),
                IsoCountryInfo(name: "Antarctica", numeric: "010", alpha2: "AQ", alpha3: "ATA", calling: "+672", currency: "AUD", continent: "AN" ),
                IsoCountryInfo(name: "Antigua and Barbuda", numeric: "028", alpha2: "AG", alpha3: "ATG", calling: "+268", currency: "XCD", continent: "NA" ),
                IsoCountryInfo(name: "Argentina", numeric: "032", alpha2: "AR", alpha3: "ARG", calling: "+54", currency: "ARS", continent: "SA" ),
                IsoCountryInfo(name: "Armenia", numeric: "051", alpha2: "AM", alpha3: "ARM", calling: "+374", currency: "AMD", continent: "AS" ),
                IsoCountryInfo(name: "Aruba", numeric: "533", alpha2: "AW", alpha3: "ABW", calling: "+297", currency: "AWG", continent: "NA" ),
                IsoCountryInfo(name: "Australia", numeric: "036", alpha2: "AU", alpha3: "AUS", calling: "+61", currency: "AUD", continent: "OC" ),
                IsoCountryInfo(name: "Austria", numeric: "040", alpha2: "AT", alpha3: "AUT", calling: "+43", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Azerbaijan", numeric: "031", alpha2: "AZ", alpha3: "AZE", calling: "+994", currency: "AZN", continent: "AS" ),
                IsoCountryInfo(name: "Bahamas", numeric: "044", alpha2: "BS", alpha3: "BHS", calling: "+242", currency: "BSD", continent: "NA" ),
                IsoCountryInfo(name: "Bahrain", numeric: "048", alpha2: "BH", alpha3: "BHR", calling: "+973", currency: "BHD", continent: "AS" ),
                IsoCountryInfo(name: "Bangladesh", numeric: "050", alpha2: "BD", alpha3: "BGD", calling: "+880", currency: "BDT", continent: "AS" ),
                IsoCountryInfo(name: "Barbados", numeric: "052", alpha2: "BB", alpha3: "BRB", calling: "+246", currency: "BBD", continent: "NA" ),
                IsoCountryInfo(name: "Belarus", numeric: "112", alpha2: "BY", alpha3: "BLR", calling: "+375", currency: "BYR", continent: "EU" ),
                IsoCountryInfo(name: "Belgium", numeric: "056", alpha2: "BE", alpha3: "BEL", calling: "+32", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Belize", numeric: "084", alpha2: "BZ", alpha3: "BLZ", calling: "+501", currency: "BZD", continent: "NA" ),
                IsoCountryInfo(name: "Benin", numeric: "204", alpha2: "BJ", alpha3: "BEN", calling: "+229", currency: "XOF", continent: "AF" ),
                IsoCountryInfo(name: "Bermuda", numeric: "060", alpha2: "BM", alpha3: "BMU", calling: "+441", currency: "BMD", continent: "NA" ),
                IsoCountryInfo(name: "Bhutan", numeric: "064", alpha2: "BT", alpha3: "BTN", calling: "+975", currency: "BTN", continent: "AS" ),
                IsoCountryInfo(name: "Bolivia, Plurinational State of", numeric: "068", alpha2: "BO", alpha3: "BOL", calling: "+591", currency: "BOB", continent: "SA" ),
                IsoCountryInfo(name: "Bonaire, Sint Eustatius and Saba", numeric: "535", alpha2: "BQ", alpha3: "BES", calling: "+599", currency: "USD", continent: "" ),
                IsoCountryInfo(name: "Bosnia and Herzegovina", numeric: "070", alpha2: "BA", alpha3: "BIH", calling: "+387", currency: "BAM", continent: "EU" ),
                IsoCountryInfo(name: "Botswana", numeric: "072", alpha2: "BW", alpha3: "BWA", calling: "+267", currency: "BWP", continent: "AF" ),
                IsoCountryInfo(name: "Bouvet Island", numeric: "074", alpha2: "BV", alpha3: "BVT", calling: "+47", currency: "NOK", continent: "AN" ),
                IsoCountryInfo(name: "Brazil", numeric: "076", alpha2: "BR", alpha3: "BRA", calling: "+55", currency: "BRL", continent: "SA" ),
                IsoCountryInfo(name: "British Indian Ocean Territory", numeric: "086", alpha2: "IO", alpha3: "IOT", calling: "+246", currency: "USD", continent: "AS" ),
                IsoCountryInfo(name: "Brunei Darussalam", numeric: "096", alpha2: "BN", alpha3: "BRN", calling: "+673", currency: "BND", continent: "AS" ),
                IsoCountryInfo(name: "Bulgaria", numeric: "100", alpha2: "BG", alpha3: "BGR", calling: "+359", currency: "BGN", continent: "EU" ),
                IsoCountryInfo(name: "Burkina Faso", numeric: "854", alpha2: "BF", alpha3: "BFA", calling: "+226", currency: "XOF", continent: "AF" ),
                IsoCountryInfo(name: "Burundi", numeric: "108", alpha2: "BI", alpha3: "BDI", calling: "+257", currency: "BIF", continent: "AF" ),
                IsoCountryInfo(name: "Cambodia", numeric: "116", alpha2: "KH", alpha3: "KHM", calling: "+855", currency: "KHR", continent: "AS" ),
                IsoCountryInfo(name: "Cameroon", numeric: "120", alpha2: "CM", alpha3: "CMR", calling: "+237", currency: "XAF", continent: "AF" ),
                IsoCountryInfo(name: "Canada", numeric: "124", alpha2: "CA", alpha3: "CAN", calling: "+1", currency: "CAD", continent: "NA" ),
                IsoCountryInfo(name: "Cabo Verde", numeric: "132", alpha2: "CV", alpha3: "CPV", calling: "+238", currency: "CVE", continent: "AF" ),
                IsoCountryInfo(name: "Cayman Islands", numeric: "136", alpha2: "KY", alpha3: "CYM", calling: "+345", currency: "KYD", continent: "NA" ),
                IsoCountryInfo(name: "Central African Republic", numeric: "140", alpha2: "CF", alpha3: "CAF", calling: "+236", currency: "XAF", continent: "AF" ),
                IsoCountryInfo(name: "Chad", numeric: "148", alpha2: "TD", alpha3: "TCD", calling: "+235", currency: "XAF", continent: "AF" ),
                IsoCountryInfo(name: "Chile", numeric: "152", alpha2: "CL", alpha3: "CHL", calling: "+56", currency: "CLP", continent: "SA" ),
                IsoCountryInfo(name: "China", numeric: "156", alpha2: "CN", alpha3: "CHN", calling: "+86", currency: "CNY", continent: "AS" ),
                IsoCountryInfo(name: "Christmas Island", numeric: "162", alpha2: "CX", alpha3: "CXR", calling: "+61", currency: "AUD", continent: "AS" ),
                IsoCountryInfo(name: "Cocos (Keeling) Islands", numeric: "166", alpha2: "CC", alpha3: "CCK", calling: "+891", currency: "AUD", continent: "AS" ),
                IsoCountryInfo(name: "Colombia", numeric: "170", alpha2: "CO", alpha3: "COL", calling: "+57", currency: "COP", continent: "SA" ),
                IsoCountryInfo(name: "Comoros", numeric: "174", alpha2: "KM", alpha3: "COM", calling: "+269", currency: "KMF", continent: "AF" ),
                IsoCountryInfo(name: "Congo", numeric: "178", alpha2: "CG", alpha3: "COG", calling: "+242", currency: "XAF", continent: "AF" ),
                IsoCountryInfo(name: "Congo, the Democratic Republic of the", numeric: "180", alpha2: "CD", alpha3: "COD", calling: "+243", currency: "CDF", continent: "AF" ),
                IsoCountryInfo(name: "Cook Islands", numeric: "184", alpha2: "CK", alpha3: "COK", calling: "+682", currency: "NZD", continent: "OC" ),
                IsoCountryInfo(name: "Costa Rica", numeric: "188", alpha2: "CR", alpha3: "CRI", calling: "+506", currency: "CRC", continent: "NA" ),
                IsoCountryInfo(name: "Côte d'Ivoire", numeric: "384", alpha2: "CI", alpha3: "CIV", calling: "+225", currency: "XOF", continent: "AF" ),
                IsoCountryInfo(name: "Croatia", numeric: "191", alpha2: "HR", alpha3: "HRV", calling: "+385", currency: "HRK", continent: "EU" ),
                IsoCountryInfo(name: "Cuba", numeric: "192", alpha2: "CU", alpha3: "CUB", calling: "+53", currency: "CUP", continent: "NA" ),
                IsoCountryInfo(name: "Curaçao", numeric: "531", alpha2: "CW", alpha3: "CUW", calling: "+599", currency: "ANG", continent: "" ),
                IsoCountryInfo(name: "Cyprus", numeric: "196", alpha2: "CY", alpha3: "CYP", calling: "+357", currency: "EUR", continent: "AS" ),
                IsoCountryInfo(name: "Czech Republic", numeric: "203", alpha2: "CZ", alpha3: "CZE", calling: "+420", currency: "CZK", continent: "EU" ),
                IsoCountryInfo(name: "Denmark", numeric: "208", alpha2: "DK", alpha3: "DNK", calling: "+45", currency: "DKK", continent: "EU" ),
                IsoCountryInfo(name: "Djibouti", numeric: "262", alpha2: "DJ", alpha3: "DJI", calling: "+253", currency: "DJF", continent: "AF" ),
                IsoCountryInfo(name: "Dominica", numeric: "212", alpha2: "DM", alpha3: "DMA", calling: "+767", currency: "XCD", continent: "NA" ),
                IsoCountryInfo(name: "Dominican Republic", numeric: "214", alpha2: "DO", alpha3: "DOM", calling: "+809", currency: "DOP", continent: "NA" ),
                IsoCountryInfo(name: "Ecuador", numeric: "218", alpha2: "EC", alpha3: "ECU", calling: "+593", currency: "USD", continent: "SA" ),
                IsoCountryInfo(name: "Egypt", numeric: "818", alpha2: "EG", alpha3: "EGY", calling: "+20", currency: "EGP", continent: "AF" ),
                IsoCountryInfo(name: "El Salvador", numeric: "222", alpha2: "SV", alpha3: "SLV", calling: "+503", currency: "SVC", continent: "NA" ),
                IsoCountryInfo(name: "Equatorial Guinea", numeric: "226", alpha2: "GQ", alpha3: "GNQ", calling: "+240", currency: "XAF", continent: "AF" ),
                IsoCountryInfo(name: "Eritrea", numeric: "232", alpha2: "ER", alpha3: "ERI", calling: "+291", currency: "ETB", continent: "AF" ),
                IsoCountryInfo(name: "Estonia", numeric: "233", alpha2: "EE", alpha3: "EST", calling: "+372", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Ethiopia", numeric: "231", alpha2: "ET", alpha3: "ETH", calling: "+251", currency: "ETB", continent: "AF" ),
                IsoCountryInfo(name: "Falkland Islands (Malvinas)", numeric: "238", alpha2: "FK", alpha3: "FLK", calling: "+500", currency: "FKP", continent: "SA" ),
                IsoCountryInfo(name: "Faroe Islands", numeric: "234", alpha2: "FO", alpha3: "FRO", calling: "+298", currency: "DKK", continent: "EU" ),
                IsoCountryInfo(name: "Fiji", numeric: "242", alpha2: "FJ", alpha3: "FJI", calling: "+679", currency: "FJD", continent: "OC" ),
                IsoCountryInfo(name: "Finland", numeric: "246", alpha2: "FI", alpha3: "FIN", calling: "+358", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "France", numeric: "250", alpha2: "FR", alpha3: "FRA", calling: "+33", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "French Guiana", numeric: "254", alpha2: "GF", alpha3: "GUF", calling: "+594", currency: "EUR", continent: "SA" ),
                IsoCountryInfo(name: "French Polynesia", numeric: "258", alpha2: "PF", alpha3: "PYF", calling: "+689", currency: "XPF", continent: "OC" ),
                IsoCountryInfo(name: "French Southern Territories", numeric: "260", alpha2: "TF", alpha3: "ATF", calling: "+689", currency: "EUR", continent: "AN" ),
                IsoCountryInfo(name: "Gabon", numeric: "266", alpha2: "GA", alpha3: "GAB", calling: "+241", currency: "XAF", continent: "AF" ),
                IsoCountryInfo(name: "Gambia", numeric: "270", alpha2: "GM", alpha3: "GMB", calling: "+220", currency: "GMD", continent: "AF" ),
                IsoCountryInfo(name: "Georgia", numeric: "268", alpha2: "GE", alpha3: "GEO", calling: "+995", currency: "GEL", continent: "AS" ),
                IsoCountryInfo(name: "Germany", numeric: "276", alpha2: "DE", alpha3: "DEU", calling: "+49", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Ghana", numeric: "288", alpha2: "GH", alpha3: "GHA", calling: "+233", currency: "GHS", continent: "AF" ),
                IsoCountryInfo(name: "Gibraltar", numeric: "292", alpha2: "GI", alpha3: "GIB", calling: "+350", currency: "GIP", continent: "EU" ),
                IsoCountryInfo(name: "Greece", numeric: "300", alpha2: "GR", alpha3: "GRC", calling: "+30", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Greenland", numeric: "304", alpha2: "GL", alpha3: "GRL", calling: "+299", currency: "DKK", continent: "NA" ),
                IsoCountryInfo(name: "Grenada", numeric: "308", alpha2: "GD", alpha3: "GRD", calling: "+473", currency: "XCD", continent: "NA" ),
                IsoCountryInfo(name: "Guadeloupe", numeric: "312", alpha2: "GP", alpha3: "GLP", calling: "+590", currency: "EUR", continent: "NA" ),
                IsoCountryInfo(name: "Guam", numeric: "316", alpha2: "GU", alpha3: "GUM", calling: "+671", currency: "USD", continent: "OC" ),
                IsoCountryInfo(name: "Guatemala", numeric: "320", alpha2: "GT", alpha3: "GTM", calling: "+502", currency: "GTQ", continent: "NA" ),
                IsoCountryInfo(name: "Guernsey", numeric: "831", alpha2: "GG", alpha3: "GGY", calling: "+1481", currency: "GGP", continent: "EU" ),
                IsoCountryInfo(name: "Guinea", numeric: "324", alpha2: "GN", alpha3: "GIN", calling: "+225", currency: "GNF", continent: "AF" ),
                IsoCountryInfo(name: "Guinea-Bissau", numeric: "624", alpha2: "GW", alpha3: "GNB", calling: "+245", currency: "XOF", continent: "AF" ),
                IsoCountryInfo(name: "Guyana", numeric: "328", alpha2: "GY", alpha3: "GUY", calling: "+592", currency: "GYD", continent: "SA" ),
                IsoCountryInfo(name: "Haiti", numeric: "332", alpha2: "HT", alpha3: "HTI", calling: "+509", currency: "HTG", continent: "NA" ),
                IsoCountryInfo(name: "Heard Island and McDonald Islands", numeric: "334", alpha2: "HM", alpha3: "HMD", calling: "+61", currency: "AUD", continent: "AN" ),
                IsoCountryInfo(name: "Holy See (Vatican City State)", numeric: "336", alpha2: "VA", alpha3: "VAT", calling: "+379", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Honduras", numeric: "340", alpha2: "HN", alpha3: "HND", calling: "+504", currency: "HNL", continent: "NA" ),
                IsoCountryInfo(name: "Hong Kong", numeric: "344", alpha2: "HK", alpha3: "HKG", calling: "+852", currency: "HKD", continent: "AS" ),
                IsoCountryInfo(name: "Hungary", numeric: "348", alpha2: "HU", alpha3: "HUN", calling: "+36", currency: "HUF", continent: "EU" ),
                IsoCountryInfo(name: "Iceland", numeric: "352", alpha2: "IS", alpha3: "ISL", calling: "+354", currency: "ISK", continent: "EU" ),
                IsoCountryInfo(name: "India", numeric: "356", alpha2: "IN", alpha3: "IND", calling: "+91", currency: "INR", continent: "AS" ),
                IsoCountryInfo(name: "Indonesia", numeric: "360", alpha2: "ID", alpha3: "IDN", calling: "+62", currency: "IDR", continent: "AS" ),
                IsoCountryInfo(name: "Iran, Islamic Republic of", numeric: "364", alpha2: "IR", alpha3: "IRN", calling: "+98", currency: "IRR", continent: "AS" ),
                IsoCountryInfo(name: "Iraq", numeric: "368", alpha2: "IQ", alpha3: "IRQ", calling: "+964", currency: "IQD", continent: "AS" ),
                IsoCountryInfo(name: "Ireland", numeric: "372", alpha2: "IE", alpha3: "IRL", calling: "+353", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Isle of Man", numeric: "833", alpha2: "IM", alpha3: "IMN", calling: "+44", currency: "IMP", continent: "EU" ),
                IsoCountryInfo(name: "Israel", numeric: "376", alpha2: "IL", alpha3: "ISR", calling: "+972", currency: "ILS", continent: "AS" ),
                IsoCountryInfo(name: "Italy", numeric: "380", alpha2: "IT", alpha3: "ITA", calling: "+39", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Jamaica", numeric: "388", alpha2: "JM", alpha3: "JAM", calling: "+876", currency: "JMD", continent: "NA" ),
                IsoCountryInfo(name: "Japan", numeric: "392", alpha2: "JP", alpha3: "JPN", calling: "+81", currency: "JPY", continent: "AS" ),
                IsoCountryInfo(name: "Jersey", numeric: "832", alpha2: "JE", alpha3: "JEY", calling: "+44", currency: "JEP", continent: "EU" ),
                IsoCountryInfo(name: "Jordan", numeric: "400", alpha2: "JO", alpha3: "JOR", calling: "+962", currency: "JOD", continent: "AS" ),
                IsoCountryInfo(name: "Kazakhstan", numeric: "398", alpha2: "KZ", alpha3: "KAZ", calling: "+7", currency: "KZT", continent: "AS" ),
                IsoCountryInfo(name: "Kenya", numeric: "404", alpha2: "KE", alpha3: "KEN", calling: "+254", currency: "KES", continent: "AF" ),
                IsoCountryInfo(name: "Kiribati", numeric: "296", alpha2: "KI", alpha3: "KIR", calling: "+686", currency: "AUD", continent: "OC" ),
                IsoCountryInfo(name: "Korea, Democratic People's Republic of", numeric: "408", alpha2: "KP", alpha3: "PRK", calling: "+850", currency: "KPW", continent: "AS" ),
                IsoCountryInfo(name: "Korea, Republic of", numeric: "410", alpha2: "KR", alpha3: "KOR", calling: "+82", currency: "KRW", continent: "AS" ),
                IsoCountryInfo(name: "Kuwait", numeric: "414", alpha2: "KW", alpha3: "KWT", calling: "+965", currency: "KWD", continent: "AS" ),
                IsoCountryInfo(name: "Kyrgyzstan", numeric: "417", alpha2: "KG", alpha3: "KGZ", calling: "+996", currency: "KGS", continent: "AS" ),
                IsoCountryInfo(name: "Lao People's Democratic Republic", numeric: "418", alpha2: "LA", alpha3: "LAO", calling: "+856", currency: "LAK", continent: "AS" ),
                IsoCountryInfo(name: "Latvia", numeric: "428", alpha2: "LV", alpha3: "LVA", calling: "+371", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Lebanon", numeric: "422", alpha2: "LB", alpha3: "LBN", calling: "+961", currency: "LBP", continent: "AS" ),
                IsoCountryInfo(name: "Lesotho", numeric: "426", alpha2: "LS", alpha3: "LSO", calling: "+266", currency: "LSL", continent: "AF" ),
                IsoCountryInfo(name: "Liberia", numeric: "430", alpha2: "LR", alpha3: "LBR", calling: "+231", currency: "LRD", continent: "AF" ),
                IsoCountryInfo(name: "Libya", numeric: "434", alpha2: "LY", alpha3: "LBY", calling: "+218", currency: "LYD", continent: "AF" ),
                IsoCountryInfo(name: "Liechtenstein", numeric: "438", alpha2: "LI", alpha3: "LIE", calling: "+423", currency: "CHF", continent: "EU" ),
                IsoCountryInfo(name: "Lithuania", numeric: "440", alpha2: "LT", alpha3: "LTU", calling: "+370", currency: "LTL", continent: "EU" ),
                IsoCountryInfo(name: "Luxembourg", numeric: "442", alpha2: "LU", alpha3: "LUX", calling: "+352", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Macao", numeric: "446", alpha2: "MO", alpha3: "MAC", calling: "+853", currency: "MOP", continent: "AS" ),
                IsoCountryInfo(name: "Macedonia, the former Yugoslav Republic of", numeric: "807", alpha2: "MK", alpha3: "MKD", calling: "+389", currency: "MKD", continent: "EU" ),
                IsoCountryInfo(name: "Madagascar", numeric: "450", alpha2: "MG", alpha3: "MDG", calling: "+261", currency: "MGA", continent: "AF" ),
                IsoCountryInfo(name: "Malawi", numeric: "454", alpha2: "MW", alpha3: "MWI", calling: "+265", currency: "MWK", continent: "AF" ),
                IsoCountryInfo(name: "Malaysia", numeric: "458", alpha2: "MY", alpha3: "MYS", calling: "+60", currency: "MYR", continent: "AS" ),
                IsoCountryInfo(name: "Maldives", numeric: "462", alpha2: "MV", alpha3: "MDV", calling: "+960", currency: "MVR", continent: "AS" ),
                IsoCountryInfo(name: "Mali", numeric: "466", alpha2: "ML", alpha3: "MLI", calling: "+223", currency: "XOF", continent: "AF" ),
                IsoCountryInfo(name: "Malta", numeric: "470", alpha2: "MT", alpha3: "MLT", calling: "+356", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Marshall Islands", numeric: "584", alpha2: "MH", alpha3: "MHL", calling: "+692", currency: "USD", continent: "OC" ),
                IsoCountryInfo(name: "Martinique", numeric: "474", alpha2: "MQ", alpha3: "MTQ", calling: "+596", currency: "EUR", continent: "NA" ),
                IsoCountryInfo(name: "Mauritania", numeric: "478", alpha2: "MR", alpha3: "MRT", calling: "+222", currency: "MRO", continent: "AF" ),
                IsoCountryInfo(name: "Mauritius", numeric: "480", alpha2: "MU", alpha3: "MUS", calling: "+230", currency: "MUR", continent: "AF" ),
                IsoCountryInfo(name: "Mayotte", numeric: "175", alpha2: "YT", alpha3: "MYT", calling: "+262", currency: "EUR", continent: "AF" ),
                IsoCountryInfo(name: "Mexico", numeric: "484", alpha2: "MX", alpha3: "MEX", calling: "+52", currency: "MXN", continent: "NA" ),
                IsoCountryInfo(name: "Micronesia, Federated States of", numeric: "583", alpha2: "FM", alpha3: "FSM", calling: "+691", currency: "USD", continent: "OC" ),
                IsoCountryInfo(name: "Moldova, Republic of", numeric: "498", alpha2: "MD", alpha3: "MDA", calling: "+373", currency: "MDL", continent: "EU" ),
                IsoCountryInfo(name: "Monaco", numeric: "492", alpha2: "MC", alpha3: "MCO", calling: "+355", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Mongolia", numeric: "496", alpha2: "MN", alpha3: "MNG", calling: "+976", currency: "MNT", continent: "AS" ),
                IsoCountryInfo(name: "Montenegro", numeric: "499", alpha2: "ME", alpha3: "MNE", calling: "+382", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Montserrat", numeric: "500", alpha2: "MS", alpha3: "MSR", calling: "+664", currency: "XCD", continent: "NA" ),
                IsoCountryInfo(name: "Morocco", numeric: "504", alpha2: "MA", alpha3: "MAR", calling: "+212", currency: "MAD", continent: "AF" ),
                IsoCountryInfo(name: "Mozambique", numeric: "508", alpha2: "MZ", alpha3: "MOZ", calling: "+258", currency: "MZN", continent: "AF" ),
                IsoCountryInfo(name: "Myanmar", numeric: "104", alpha2: "MM", alpha3: "MMR", calling: "+95", currency: "MMK", continent: "AS" ),
                IsoCountryInfo(name: "Namibia", numeric: "516", alpha2: "NA", alpha3: "NAM", calling: "+264", currency: "NAD", continent: "AF" ),
                IsoCountryInfo(name: "Nauru", numeric: "520", alpha2: "NR", alpha3: "NRU", calling: "+674", currency: "AUD", continent: "OC" ),
                IsoCountryInfo(name: "Nepal", numeric: "524", alpha2: "NP", alpha3: "NPL", calling: "+977", currency: "NPR", continent: "AS" ),
                IsoCountryInfo(name: "Netherlands", numeric: "528", alpha2: "NL", alpha3: "NLD", calling: "+31", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "New Caledonia", numeric: "540", alpha2: "NC", alpha3: "NCL", calling: "+687", currency: "XPF", continent: "OC" ),
                IsoCountryInfo(name: "New Zealand", numeric: "554", alpha2: "NZ", alpha3: "NZL", calling: "+64", currency: "NZD", continent: "OC" ),
                IsoCountryInfo(name: "Nicaragua", numeric: "558", alpha2: "NI", alpha3: "NIC", calling: "+505", currency: "NIO", continent: "NA" ),
                IsoCountryInfo(name: "Niger", numeric: "562", alpha2: "NE", alpha3: "NER", calling: "+277", currency: "XOF", continent: "AF" ),
                IsoCountryInfo(name: "Nigeria", numeric: "566", alpha2: "NG", alpha3: "NGA", calling: "+234", currency: "NGN", continent: "AF" ),
                IsoCountryInfo(name: "Niue", numeric: "570", alpha2: "NU", alpha3: "NIU", calling: "+683", currency: "NZD", continent: "OC" ),
                IsoCountryInfo(name: "Norfolk Island", numeric: "574", alpha2: "NF", alpha3: "NFK", calling: "+672", currency: "AUD", continent: "OC" ),
                IsoCountryInfo(name: "Northern Mariana Islands", numeric: "580", alpha2: "MP", alpha3: "MNP", calling: "+670", currency: "USD", continent: "OC" ),
                IsoCountryInfo(name: "Norway", numeric: "578", alpha2: "NO", alpha3: "NOR", calling: "+47", currency: "NOK", continent: "EU" ),
                IsoCountryInfo(name: "Oman", numeric: "512", alpha2: "OM", alpha3: "OMN", calling: "+968", currency: "OMR", continent: "AS" ),
                IsoCountryInfo(name: "Pakistan", numeric: "586", alpha2: "PK", alpha3: "PAK", calling: "+92", currency: "PKR", continent: "AS" ),
                IsoCountryInfo(name: "Palau", numeric: "585", alpha2: "PW", alpha3: "PLW", calling: "+680", currency: "USD", continent: "OC" ),
                IsoCountryInfo(name: "Palestine, State of", numeric: "275", alpha2: "PS", alpha3: "PSE", calling: "+970", currency: "JOD", continent: "AS" ),
                IsoCountryInfo(name: "Panama", numeric: "591", alpha2: "PA", alpha3: "PAN", calling: "+507", currency: "PAB", continent: "NA" ),
                IsoCountryInfo(name: "Papua New Guinea", numeric: "598", alpha2: "PG", alpha3: "PNG", calling: "+675", currency: "PGK", continent: "OC" ),
                IsoCountryInfo(name: "Paraguay", numeric: "600", alpha2: "PY", alpha3: "PRY", calling: "+595", currency: "PYG", continent: "SA" ),
                IsoCountryInfo(name: "Peru", numeric: "604", alpha2: "PE", alpha3: "PER", calling: "+51", currency: "PEN", continent: "SA" ),
                IsoCountryInfo(name: "Philippines", numeric: "608", alpha2: "PH", alpha3: "PHL", calling: "+63", currency: "PHP", continent: "AS" ),
                IsoCountryInfo(name: "Pitcairn", numeric: "612", alpha2: "PN", alpha3: "PCN", calling: "+872", currency: "NZD", continent: "OC" ),
                IsoCountryInfo(name: "Poland", numeric: "616", alpha2: "PL", alpha3: "POL", calling: "+48", currency: "PLN", continent: "EU" ),
                IsoCountryInfo(name: "Portugal", numeric: "620", alpha2: "PT", alpha3: "PRT", calling: "+351", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Puerto Rico", numeric: "630", alpha2: "PR", alpha3: "PRI", calling: "+787", currency: "USD", continent: "NA" ),
                IsoCountryInfo(name: "Qatar", numeric: "634", alpha2: "QA", alpha3: "QAT", calling: "+974", currency: "QAR", continent: "AS" ),
                IsoCountryInfo(name: "Réunion", numeric: "638", alpha2: "RE", alpha3: "REU", calling: "+262", currency: "EUR", continent: "AF" ),
                IsoCountryInfo(name: "Romania", numeric: "642", alpha2: "RO", alpha3: "ROU", calling: "+40", currency: "RON", continent: "EU" ),
                IsoCountryInfo(name: "Russian Federation", numeric: "643", alpha2: "RU", alpha3: "RUS", calling: "+7", currency: "RUB", continent: "EU" ),
                IsoCountryInfo(name: "Rwanda", numeric: "646", alpha2: "RW", alpha3: "RWA", calling: "+250", currency: "RWF", continent: "AF" ),
                IsoCountryInfo(name: "Saint Barthélemy", numeric: "652", alpha2: "BL", alpha3: "BLM", calling: "+590", currency: "EUR", continent: "NA" ),
                IsoCountryInfo(name: "Saint Helena, Ascension and Tristan da Cunha", numeric: "654", alpha2: "SH", alpha3: "SHN", calling: "+290", currency: "SHP", continent: "AF" ),
                IsoCountryInfo(name: "Saint Kitts and Nevis", numeric: "659", alpha2: "KN", alpha3: "KNA", calling: "+869", currency: "XCD", continent: "NA" ),
                IsoCountryInfo(name: "Saint Lucia", numeric: "662", alpha2: "LC", alpha3: "LCA", calling: "+758", currency: "XCD", continent: "NA" ),
                IsoCountryInfo(name: "Saint Martin (French part)", numeric: "663", alpha2: "MF", alpha3: "MAF", calling: "+590", currency: "EUR", continent: "NA" ),
                IsoCountryInfo(name: "Saint Pierre and Miquelon", numeric: "666", alpha2: "PM", alpha3: "SPM", calling: "+508", currency: "EUR", continent: "NA" ),
                IsoCountryInfo(name: "Saint Vincent and the Grenadines", numeric: "670", alpha2: "VC", alpha3: "VCT", calling: "+784", currency: "XCD", continent: "NA" ),
                IsoCountryInfo(name: "Samoa", numeric: "882", alpha2: "WS", alpha3: "WSM", calling: "+685", currency: "WST", continent: "OC" ),
                IsoCountryInfo(name: "San Marino", numeric: "674", alpha2: "SM", alpha3: "SMR", calling: "+378", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Sao Tome and Principe", numeric: "678", alpha2: "ST", alpha3: "STP", calling: "+239", currency: "STD", continent: "AF" ),
                IsoCountryInfo(name: "Saudi Arabia", numeric: "682", alpha2: "SA", alpha3: "SAU", calling: "+966", currency: "SAR", continent: "AS" ),
                IsoCountryInfo(name: "Senegal", numeric: "686", alpha2: "SN", alpha3: "SEN", calling: "+221", currency: "XOF", continent: "AF" ),
                IsoCountryInfo(name: "Serbia", numeric: "688", alpha2: "RS", alpha3: "SRB", calling: "+381", currency: "RSD", continent: "EU" ),
                IsoCountryInfo(name: "Seychelles", numeric: "690", alpha2: "SC", alpha3: "SYC", calling: "+248", currency: "SCR", continent: "AF" ),
                IsoCountryInfo(name: "Sierra Leone", numeric: "694", alpha2: "SL", alpha3: "SLE", calling: "+232", currency: "SLL", continent: "AF" ),
                IsoCountryInfo(name: "Singapore", numeric: "702", alpha2: "SG", alpha3: "SGP", calling: "+65", currency: "SGD", continent: "AS" ),
                IsoCountryInfo(name: "Sint Maarten (Dutch part)", numeric: "534", alpha2: "SX", alpha3: "SXM", calling: "+599", currency: "ANG", continent: "" ),
                IsoCountryInfo(name: "Slovakia", numeric: "703", alpha2: "SK", alpha3: "SVK", calling: "+421", currency: "SKK", continent: "EU" ),
                IsoCountryInfo(name: "Slovenia", numeric: "705", alpha2: "SI", alpha3: "SVN", calling: "+386", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Solomon Islands", numeric: "090", alpha2: "SB", alpha3: "SLB", calling: "+677", currency: "SBD", continent: "OC" ),
                IsoCountryInfo(name: "Somalia", numeric: "706", alpha2: "SO", alpha3: "SOM", calling: "+252", currency: "SOS", continent: "AF" ),
                IsoCountryInfo(name: "South Africa", numeric: "710", alpha2: "ZA", alpha3: "ZAF", calling: "+27", currency: "ZAR", continent: "AF" ),
                IsoCountryInfo(name: "South Georgia and the South Sandwich Islands", numeric: "239", alpha2: "GS", alpha3: "SGS", calling: "+500", currency: "GBP", continent: "AN" ),
                IsoCountryInfo(name: "South Sudan", numeric: "728", alpha2: "SS", alpha3: "SSD", calling: "+211", currency: "SSP", continent: "" ),
                IsoCountryInfo(name: "Spain", numeric: "724", alpha2: "ES", alpha3: "ESP", calling: "+34", currency: "EUR", continent: "EU" ),
                IsoCountryInfo(name: "Sri Lanka", numeric: "144", alpha2: "LK", alpha3: "LKA", calling: "+94", currency: "LKR", continent: "AS" ),
                IsoCountryInfo(name: "Sudan", numeric: "729", alpha2: "SD", alpha3: "SDN", calling: "+249", currency: "SDG", continent: "AF" ),
                IsoCountryInfo(name: "Suriname", numeric: "740", alpha2: "SR", alpha3: "SUR", calling: "+597", currency: "SRD", continent: "SA" ),
                IsoCountryInfo(name: "Svalbard and Jan Mayen", numeric: "744", alpha2: "SJ", alpha3: "SJM", calling: "+47", currency: "NOK", continent: "EU" ),
                IsoCountryInfo(name: "Swaziland", numeric: "748", alpha2: "SZ", alpha3: "SWZ", calling: "+268", currency: "CHF", continent: "AF" ),
                IsoCountryInfo(name: "Sweden", numeric: "752", alpha2: "SE", alpha3: "SWE", calling: "+46", currency: "SEK", continent: "EU" ),
                IsoCountryInfo(name: "Switzerland", numeric: "756", alpha2: "CH", alpha3: "CHE", calling: "+41", currency: "CHF", continent: "EU" ),
                IsoCountryInfo(name: "Syrian Arab Republic", numeric: "760", alpha2: "SY", alpha3: "SYR", calling: "+963", currency: "SYP", continent: "AS" ),
                IsoCountryInfo(name: "Taiwan, Province of China", numeric: "158", alpha2: "TW", alpha3: "TWN", calling: "+886", currency: "TWD", continent: "AS" ),
                IsoCountryInfo(name: "Tajikistan", numeric: "762", alpha2: "TJ", alpha3: "TJK", calling: "+992", currency: "TJS", continent: "AS" ),
                IsoCountryInfo(name: "Tanzania, United Republic of", numeric: "834", alpha2: "TZ", alpha3: "TZA", calling: "+255", currency: "TZS", continent: "AF" ),
                IsoCountryInfo(name: "Thailand", numeric: "764", alpha2: "TH", alpha3: "THA", calling: "+66", currency: "THB", continent: "AS" ),
                IsoCountryInfo(name: "Timor-Leste", numeric: "626", alpha2: "TL", alpha3: "TLS", calling: "+670", currency: "IDR", continent: "AS" ),
                IsoCountryInfo(name: "Togo", numeric: "768", alpha2: "TG", alpha3: "TGO", calling: "+228", currency: "XOF", continent: "AF" ),
                IsoCountryInfo(name: "Tokelau", numeric: "772", alpha2: "TK", alpha3: "TKL", calling: "+690", currency: "NZD", continent: "OC" ),
                IsoCountryInfo(name: "Tonga", numeric: "776", alpha2: "TO", alpha3: "TON", calling: "+676", currency: "TOP", continent: "OC" ),
                IsoCountryInfo(name: "Trinidad and Tobago", numeric: "780", alpha2: "TT", alpha3: "TTO", calling: "+868", currency: "TTD", continent: "NA" ),
                IsoCountryInfo(name: "Tunisia", numeric: "788", alpha2: "TN", alpha3: "TUN", calling: "+216", currency: "TND", continent: "AF" ),
                IsoCountryInfo(name: "Turkey", numeric: "792", alpha2: "TR", alpha3: "TUR", calling: "+90", currency: "TRY", continent: "EU" ),
                IsoCountryInfo(name: "Turkmenistan", numeric: "795", alpha2: "TM", alpha3: "TKM", calling: "+993", currency: "TMM", continent: "AS" ),
                IsoCountryInfo(name: "Turks and Caicos Islands", numeric: "796", alpha2: "TC", alpha3: "TCA", calling: "+649", currency: "USD", continent: "NA" ),
                IsoCountryInfo(name: "Tuvalu", numeric: "798", alpha2: "TV", alpha3: "TUV", calling: "+688", currency: "TVD", continent: "OC" ),
                IsoCountryInfo(name: "Uganda", numeric: "800", alpha2: "UG", alpha3: "UGA", calling: "+256", currency: "UGX", continent: "AF" ),
                IsoCountryInfo(name: "Ukraine", numeric: "804", alpha2: "UA", alpha3: "UKR", calling: "+380", currency: "UAH", continent: "EU" ),
                IsoCountryInfo(name: "United Arab Emirates", numeric: "784", alpha2: "AE", alpha3: "ARE", calling: "+971", currency: "AED", continent: "AS" ),
                IsoCountryInfo(name: "United Kingdom", numeric: "826", alpha2: "GB", alpha3: "GBR", calling: "+44", currency: "GBP", continent: "EU" ),
                IsoCountryInfo(name: "United States", numeric: "840", alpha2: "US", alpha3: "USA", calling: "+1", currency: "USD", continent: "NA" ),
                IsoCountryInfo(name: "United States Minor Outlying Islands", numeric: "581", alpha2: "UM", alpha3: "UMI", calling: "+1", currency: "USD", continent: "OC" ),
                IsoCountryInfo(name: "Uruguay", numeric: "858", alpha2: "UY", alpha3: "URY", calling: "+598", currency: "UYU", continent: "SA" ),
                IsoCountryInfo(name: "Uzbekistan", numeric: "860", alpha2: "UZ", alpha3: "UZB", calling: "+998", currency: "UZS", continent: "AS" ),
                IsoCountryInfo(name: "Vanuatu", numeric: "548", alpha2: "VU", alpha3: "VUT", calling: "+678", currency: "VUV", continent: "OC" ),
                IsoCountryInfo(name: "Venezuela, Bolivarian Republic of", numeric: "862", alpha2: "VE", alpha3: "VEN", calling: "+58", currency: "VEF", continent: "SA" ),
                IsoCountryInfo(name: "Vietnam", numeric: "704", alpha2: "VN", alpha3: "VNM", calling: "+84", currency: "VND", continent: "AS" ),
                IsoCountryInfo(name: "Virgin Islands, British", numeric: "092", alpha2: "VG", alpha3: "VGB", calling: "+284", currency: "USD", continent: "NA" ),
                IsoCountryInfo(name: "Virgin Islands, U.S.", numeric: "850", alpha2: "VI", alpha3: "VIR", calling: "+340", currency: "USD", continent: "NA" ),
                IsoCountryInfo(name: "Wallis and Futuna", numeric: "876", alpha2: "WF", alpha3: "WLF", calling: "+681", currency: "XPF", continent: "OC" ),
                IsoCountryInfo(name: "Western Sahara", numeric: "732", alpha2: "EH", alpha3: "ESH", calling: "+212", currency: "MAD", continent: "AF" ),
                IsoCountryInfo(name: "Yemen", numeric: "887", alpha2: "YE", alpha3: "YEM", calling: "+967", currency: "YER", continent: "AS" ),
                IsoCountryInfo(name: "Zambia", numeric: "894", alpha2: "ZM", alpha3: "ZMB", calling: "+260", currency: "ZMW", continent: "AF" ),
                IsoCountryInfo(name: "Zimbabwe", numeric: "716", alpha2: "ZW", alpha3: "ZWE", calling: "+263", currency: "ZWD", continent: "AF" )]
        }
    }
    
}
