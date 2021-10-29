import Foundation
import Display
import SwiftSignalKit
import Postbox
import AccountContext
import OverlayStatusController
import UrlWhitelist

public func openUserGeneratedUrl(context: AccountContext, peerId: PeerId?, url: String, concealed: Bool, skipUrlAuth: Bool = false, skipConcealedAlert: Bool = false, present: @escaping (ViewController) -> Void, openResolved: @escaping (ResolvedUrl) -> Void) {
    var concealed = concealed
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
    let openImpl: () -> Void = {
        let disposable = MetaDisposable()
        var cancelImpl: (() -> Void)?
        let progressSignal = Signal<Never, NoError> { subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                cancelImpl?()
            }))
            present(controller)
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        
        cancelImpl = {
            disposable.dispose()
        }
        disposable.set((context.sharedContext.resolveUrl(context: context, peerId: peerId, url: url, skipUrlAuth: skipUrlAuth)
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).start(next: { result in
            progressDisposable.dispose()
            openResolved(result)
        }))
    }
    
    let (parsedString, parsedConcealed) = parseUrl(url: url, wasConcealed: concealed)
    concealed = parsedConcealed
    
    if concealed && !skipConcealedAlert {
        var rawDisplayUrl: String = parsedString
        let maxLength = 180
        if rawDisplayUrl.count > maxLength {
            rawDisplayUrl = String(rawDisplayUrl[..<rawDisplayUrl.index(rawDisplayUrl.startIndex, offsetBy: maxLength - 2)]) + "..."
        }
        var displayUrl = rawDisplayUrl
        displayUrl = displayUrl.replacingOccurrences(of: "\u{202e}", with: "")
        present(textAlertController(context: context, title: nil, text: presentationData.strings.Generic_OpenHiddenLinkAlert(displayUrl).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
            openImpl()
        })]))
    } else {
        openImpl()
    }
}
