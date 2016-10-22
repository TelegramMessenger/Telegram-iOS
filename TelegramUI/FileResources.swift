import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

func fileInteractiveFetched(account: Account, file: TelegramMediaFile) -> Signal<Void, NoError> {
    return account.postbox.mediaBox.fetchedResource(file.resource)
}

func fileCancelInteractiveFetch(account: Account, file: TelegramMediaFile) {
    account.postbox.mediaBox.cancelInteractiveResourceFetch(file.resource)
}
