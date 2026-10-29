import Foundation
import SwiftSignalKit

// Whether a message open is still on its way, so that repeated taps on the media do not open it again.
// `blockInteraction` is the open's `OpenChatMessageParams.blockInteraction`. An open that never reports on it is
// blocked for `unannouncedTimeout`; one that reports `true` (a gallery, which appears only once its first item is
// ready) stays blocked until it reports `false`, or for `announcedTimeout` should it never do. Subscribe before the open
// reports anything: a value already held when subscribing does not cancel `unannouncedTimeout`.
public func chatIsOpeningMedia(blockInteraction: Signal<Bool, NoError>, unannouncedTimeout: Double, announcedTimeout: Double, queue: Queue) -> Signal<Bool, NoError> {
    let reported = blockInteraction
    |> mapToSignal { value -> Signal<Bool, NoError> in
        if value {
            return .single(true)
            |> then(.single(false) |> delay(announcedTimeout, queue: queue))
        } else {
            return .single(false)
        }
    }
    return .single(true)
    |> then(reported |> timeout(unannouncedTimeout, queue: queue, alternate: .single(false)))
}
