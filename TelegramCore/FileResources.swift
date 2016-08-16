import Foundation
import Postbox
import SwiftSignalKit

func fileResource(_ file: TelegramMediaFile) -> CloudFileMediaResource {
    return CloudFileMediaResource(location: file.location, size: file.size)
}

func fileInteractiveFetched(account: Account, file: TelegramMediaFile) -> Signal<Void, NoError> {
    return account.postbox.mediaBox.fetchedResource(fileResource(file))
}

func fileCancelInteractiveFetch(account: Account, file: TelegramMediaFile) {
    account.postbox.mediaBox.cancelInteractiveResourceFetch(fileResource(file))
}
