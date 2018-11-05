#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
#else
import Postbox
import SwiftSignalKit
import MtProtoKitDynamic
#endif

public enum RequestLocalizationPreviewError {
    case generic
}

public func requestLocalizationPreview(network: Network, identifier: String) -> Signal<LocalizationInfo, RequestLocalizationPreviewError> {
    return network.request(Api.functions.langpack.getLanguage(langPack: "", langCode: identifier))
    |> mapError { _ -> RequestLocalizationPreviewError in
        return .generic
    }
    |> map { language -> LocalizationInfo in
        return LocalizationInfo(apiLanguage: language)
    }
}
