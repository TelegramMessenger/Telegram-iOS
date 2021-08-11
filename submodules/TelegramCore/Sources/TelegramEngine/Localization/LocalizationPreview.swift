import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi


public enum RequestLocalizationPreviewError {
    case generic
}

func _internal_requestLocalizationPreview(network: Network, identifier: String) -> Signal<LocalizationInfo, RequestLocalizationPreviewError> {
    return network.request(Api.functions.langpack.getLanguage(langPack: "", langCode: identifier))
    |> mapError { _ -> RequestLocalizationPreviewError in
        return .generic
    }
    |> map { language -> LocalizationInfo in
        return LocalizationInfo(apiLanguage: language)
    }
}
