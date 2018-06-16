import Foundation
import Postbox
import SwiftSignalKit

final class InteractiveChatLinkPreviewsResult {
    let f: (Bool) -> Void
    
    init(_ f: @escaping (Bool) -> Void) {
        self.f = f
    }
}

func interactiveChatLinkPreviewsEnabled(postbox: Postbox, displayAlert: @escaping (InteractiveChatLinkPreviewsResult) -> Void) -> Signal<Bool, NoError> {
    return ApplicationSpecificNotice.getSecretChatLinkPreviews(postbox: postbox)
    |> mapToSignal { value -> Signal<Bool, NoError> in
        if let value = value {
            return .single(value)
        } else {
            return Signal { subscriber in
                Queue.mainQueue().async {
                    displayAlert(InteractiveChatLinkPreviewsResult({ result in
                        let _ = ApplicationSpecificNotice.setSecretChatLinkPreviews(postbox: postbox, value: result).start()
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                    }))
                }
                return EmptyDisposable
            }
        }
    }
}
