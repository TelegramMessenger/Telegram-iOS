import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
#else
import Postbox
import SwiftSignalKit
import MtProtoKitDynamic
#endif

public func requestTermsOfService(network: Network, countryCode: String) -> Signal<String, NoError> {
    let langCode: String
    if let langPackCode = network.context.apiEnvironment.langPackCode, !langPackCode.isEmpty {
        langCode = langPackCode
    } else {
        langCode = "en"
    }
    return network.request(Api.functions.help.getTermsOfService(countryIso2: countryCode, langCode: langCode))
    |> `catch` { _ -> Signal<Api.help.TermsOfService, NoError> in
        return .single(.termsOfService(text: ""))
    }
    |> map { result -> String in
        switch result {
        case let .termsOfService(text):
            return text
        }
    }
}
