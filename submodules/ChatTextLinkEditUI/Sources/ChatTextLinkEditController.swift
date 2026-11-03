import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import UrlEscaping
import ComponentFlow
import AlertComponent
import AlertMultilineInputFieldComponent
import AlertWebpagePreviewComponent

public func chatTextLinkEditController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    text: String,
    link: String?,
    preview: Bool = false,
    apply: @escaping (String?, TelegramMediaWebpage?) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings

    let inputState = AlertMultilineInputFieldComponent.ExternalState()

    var applyImpl: (() -> Void)?

    var effectiveUpdatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)
    if let updatedPresentationData {
        effectiveUpdatedPresentationData = updatedPresentationData
    } else {
        effectiveUpdatedPresentationData = (presentationData, context.sharedContext.presentationData)
    }

    let makeContent: (TelegramMediaWebpage?) -> [AnyComponentWithIdentity<AlertComponentEnvironment>] = { webpage in
        var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
        content.append(AnyComponentWithIdentity(
            id: "title",
            component: AnyComponent(
                AlertTitleComponent(title: link != nil ? strings.TextFormat_EditLinkTitle : strings.TextFormat_AddLinkTitle)
            )
        ))
        content.append(AnyComponentWithIdentity(
            id: "text",
            component: AnyComponent(
                AlertTextComponent(content: .plain(text))
            )
        ))
        content.append(AnyComponentWithIdentity(
            id: "input",
            component: AnyComponent(
                AlertMultilineInputFieldComponent(
                    context: context,
                    initialValue: link.flatMap { NSAttributedString(string: $0) },
                    placeholder: strings.TextFormat_AddLinkPlaceholder,
                    returnKeyType: .done,
                    keyboardType: .URL,
                    autocapitalizationType: .none,
                    autocorrectionType: .no,
                    isInitiallyFocused: true,
                    externalState: inputState,
                    returnKeyAction: {
                        applyImpl?()
                    }
                )
            )
        ))
        if let webpage {
            content.append(AnyComponentWithIdentity(
                id: "webpagePreview",
                component: AnyComponent(AlertWebpagePreviewComponent(
                    context: context,
                    presentationData: effectiveUpdatedPresentationData.0,
                    webpage: webpage
                ))
            ))
        }
        return content
    }

    let contentPromise = Promise<[AnyComponentWithIdentity<AlertComponentEnvironment>]>()
    contentPromise.set(.single(makeContent(nil)))

    var dismissImpl: (() -> Void)?
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        contentSignal: contentPromise.get(),
        actionsSignal: .single([
            .init(title: strings.Common_Cancel),
            .init(title: strings.Common_Done, type: .default, action: {
                applyImpl?()
            }, autoDismiss: false)
        ]),
        updatedPresentationData: effectiveUpdatedPresentationData
    )

    let previewDisposable = MetaDisposable()
    var currentPreview: (link: String, webpage: TelegramMediaWebpage)?
    if preview {
        var currentDisplayedPreview: (link: String, webpage: TelegramMediaWebpage?)?
        previewDisposable.set((inputState.valueSignal
        |> map { value -> String in
            return explicitUrl(value.string)
        }
        |> distinctUntilChanged
        |> mapToSignal { link -> Signal<(String, TelegramMediaWebpage?), NoError> in
            guard !link.isEmpty && isValidUrl(link, validSchemes: ["http": true, "https": true, "tg": false, "ton": false, "tonsite": true]) else {
                return .single((link, nil))
            }

            let previewSignal = webpagePreview(account: context.account, urls: [link])
            |> map { result -> (String, TelegramMediaWebpage?) in
                guard case let .result(result) = result, let webpage = result?.webpage, case .Loaded = webpage.content else {
                    return (link, nil)
                }
                return (link, webpage)
            }

            return .single((link, nil))
            |> then((.complete() |> delay(1.0, queue: Queue.mainQueue())) |> then(previewSignal))
        }
        |> deliverOnMainQueue).startStrict(next: { link, webpage in
            if let currentDisplayedPreview, currentDisplayedPreview.link == link && currentDisplayedPreview.webpage == webpage {
                return
            }
            currentDisplayedPreview = (link, webpage)
            if let webpage {
                currentPreview = (link, webpage)
            } else {
                currentPreview = nil
            }
            contentPromise.set(.single(makeContent(webpage)))
        }))
    }
    alertController.dismissed = { _ in
        previewDisposable.dispose()
    }

    applyImpl = {
        let updatedLink = explicitUrl(inputState.value.string)
        if !updatedLink.isEmpty && isValidUrl(updatedLink, validSchemes: ["http": true, "https": true, "tg": false, "ton": false, "tonsite": true]) {
            dismissImpl?()
            apply(updatedLink, currentPreview?.link == updatedLink ? currentPreview?.webpage : nil)
        } else if inputState.value.string.isEmpty {
            dismissImpl?()
            apply("", nil)
        } else {
            inputState.animateError()
        }
    }
    dismissImpl = { [weak alertController] in
        alertController?.dismiss(completion: nil)
    }

    if link == nil {
        Queue.mainQueue().after(0.1, {
            let pasteboard = UIPasteboard.general
            if pasteboard.hasURLs {
                if inputState.value.string.isEmpty, let url = pasteboard.url?.absoluteString, !url.isEmpty {
                    let value = NSAttributedString(string: url)
                    inputState.setValue(value, selectionRange: 0 ..< value.length)
                }
            }
        })
    }

    return alertController
}
