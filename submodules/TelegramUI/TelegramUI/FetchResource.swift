import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

func fetchResource(account: Account, resource: MediaResource, intervals: Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>? {
    return nil
}

