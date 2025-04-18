import Foundation
import Display
import SwiftSignalKit
import Postbox
import AccountContext
import OverlayStatusController
import UrlWhitelist
import TelegramPresentationData

public func openUserGeneratedUrl(context: AccountContext, peerId: PeerId?, url: String, concealed: Bool, skipUrlAuth: Bool = false, skipConcealedAlert: Bool = false, forceDark: Bool = false, present: @escaping (ViewController) -> Void, openResolved: @escaping (ResolvedUrl) -> Void, progress: Promise<Bool>? = nil, alertDisplayUpdated: ((ViewController?) -> Void)? = nil) -> Disposable {
    var concealed = concealed
    
    var presentationData = context.sharedContext.currentPresentationData.with { $0 }
    if forceDark {
        presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
    }
    
    let openImpl: () -> Disposable = {
        let disposable = MetaDisposable()
        var cancelImpl: (() -> Void)?
        let progressSignal: Signal<Never, NoError>
        
        if let progress {
            progressSignal = Signal<Never, NoError> { subscriber in
                progress.set(.single(true))
                return ActionDisposable {
                    progress.set(.single(false))
                }
            }
            |> runOn(Queue.mainQueue())
        } else {
            progressSignal = Signal<Never, NoError> { subscriber in
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
        }
        let progressDisposable = MetaDisposable()
        var didStartProgress = false
        
        cancelImpl = {
            disposable.dispose()
        }
        
        var resolveSignal: Signal<ResolveUrlResult, NoError>
        resolveSignal = context.sharedContext.resolveUrlWithProgress(context: context, peerId: peerId, url: url, skipUrlAuth: skipUrlAuth)
        #if DEBUG
        //resolveSignal = .single(.progress) |> then(resolveSignal |> delay(2.0, queue: .mainQueue()))
        #endif
        
        disposable.set((resolveSignal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).start(next: { result in
            switch result {
            case .progress:
                if !didStartProgress {
                    didStartProgress = true
                    progressDisposable.set(progressSignal.start())
                }
            case let .result(result):
                progressDisposable.dispose()
                openResolved(result)
            }
        }))
        
        return ActionDisposable {
            cancelImpl?()
        }
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
        let disposable = MetaDisposable()
        
        let alertController = textAlertController(context: context, forceTheme: forceDark ? presentationData.theme : nil, title: nil, text: presentationData.strings.Generic_OpenHiddenLinkAlert(displayUrl).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
            disposable.set(openImpl())
        })])
        alertController.dismissed = {  _ in
            alertDisplayUpdated?(nil)
        }
        present(alertController)
        alertDisplayUpdated?(alertController)
        return disposable
    } else {
        return openImpl()
    }
}
