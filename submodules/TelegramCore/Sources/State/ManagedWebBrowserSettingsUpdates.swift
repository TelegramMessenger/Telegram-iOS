import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

func managedWebBrowserSettingsUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return (_internal_getAccountWebBrowserSettings(postbox: postbox, network: network)
        |> ignoreValues).start(completed: {
            subscriber.putCompletion()
        })
    }
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
