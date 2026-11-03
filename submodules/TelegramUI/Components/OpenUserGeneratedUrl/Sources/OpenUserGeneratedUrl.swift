import Foundation
import UIKit
import Display
import SwiftSignalKit
import ComponentFlow
import TelegramCore
import AccountContext
import OverlayStatusController
import UrlWhitelist
import TelegramPresentationData
import AlertComponent
import AlertCheckComponent
import AlertWebpagePreviewComponent
import UrlHandling

public func openUserGeneratedUrl(
    context: AccountContext,
    peerId: EnginePeer.Id?,
    url: String,
    webpage: TelegramMediaWebpage? = nil,
    concealed: Bool,
    forceConcealed: Bool = false,
    skipUrlAuth: Bool = false,
    skipConcealedAlert: Bool = false,
    forceDark: Bool = false,
    present: @escaping (ViewController) -> Void,
    openResolved: @escaping (ResolvedUrl) -> Void,
    progress: Promise<Bool>? = nil,
    alertDisplayUpdated: ((ViewController?) -> Void)? = nil,
    concealedAlertOption: OpenUserGeneratedUrlConcealedAlertOption? = nil
) -> Disposable {
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
                let controller = OverlayStatusController(style: presentationData.theme.actionSheet.backgroundType == .light ? .light : .dark, type: .loading(cancelled: {
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

    // A login part hides the host the link opens (see `externalUrlWithLoginPart`).
    let loginPartUrl = externalUrlWithLoginPart(url)

    if forceConcealed || loginPartUrl != nil {
        concealed = true
    } else if let parsedUrl = parseInternalUrl(sharedContext: context.sharedContext, context: context, query: url) {
        if case .proxy = parsedUrl {
            concealed = true
        }
    }

    if concealed && !skipConcealedAlert {
        // For a login part the prompt shows the host the link really opens. The external-URL opener asks about such
        // a link as well, so accepting it here tells the opener it has been confirmed.
        let displayUrl = loginPartUrl.map { urlRemovingLoginPart($0).absoluteString } ?? parsedString

        let disposable = MetaDisposable()
        let checkState = concealedAlertOption.map { _ in AlertCheckComponent.ExternalState() }

        var updatedPresentationDataSignal = context.sharedContext.presentationData
        if forceDark {
            updatedPresentationDataSignal = .single(presentationData)
        }
        let controller = openLinkConfirmationController(
            context: context,
            presentationData: presentationData,
            updatedPresentationData: updatedPresentationDataSignal,
            displayUrl: displayUrl,
            webpage: webpage,
            check: concealedAlertOption.flatMap { option in checkState.map { (title: option.title, state: $0) } },
            open: {
                if let loginPartUrl {
                    noteLoginPartConfirmed(loginPartUrl)
                }
                if checkState?.value == true {
                    concealedAlertOption?.action()
                }
                disposable.set(openImpl())
            }
        )
        controller.dismissed = {  _ in
            alertDisplayUpdated?(nil)
        }
        present(controller)
        alertDisplayUpdated?(controller)
        return disposable
    } else {
        return openImpl()
    }
}

/// The "Open this link?" prompt. `displayUrl` is shortened, stripped of right-to-left overrides and has its host
/// punycoded before it is shown.
public func openLinkConfirmationController(
    context: AccountContext,
    presentationData: PresentationData,
    updatedPresentationData: Signal<PresentationData, NoError>,
    displayUrl: String,
    webpage: TelegramMediaWebpage? = nil,
    check: (title: String, state: AlertCheckComponent.ExternalState)? = nil,
    open: @escaping () -> Void
) -> AlertScreen {
    var rawDisplayUrl: String = displayUrl
    let maxLength = 180
    if rawDisplayUrl.count > maxLength {
        rawDisplayUrl = String(rawDisplayUrl[..<rawDisplayUrl.index(rawDisplayUrl.startIndex, offsetBy: maxLength - 2)]) + "..."
    }

    var shownUrl = rawDisplayUrl
    shownUrl = shownUrl.replacingOccurrences(of: "\u{202e}", with: "")
    shownUrl = (try? punycodedFullURLString(shownUrl)) ?? shownUrl

    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(id: "title", component: AnyComponent(AlertTitleComponent(title: presentationData.strings.OpenLinkConfirmation_Title))))
    content.append(AnyComponentWithIdentity(id: "text", component: AnyComponent(AlertTextComponent(
        content: .plain(shownUrl),
        alignment: .center,
        color: .primary,
        style: .background(.default),
        insets: UIEdgeInsets(top: 9.0, left: 4.0, bottom: 0.0, right: 4.0)
    ))))
    if let webpage, case .Loaded = webpage.content {
        content.append(AnyComponentWithIdentity(id: "webpagePreview", component: AnyComponent(AlertWebpagePreviewComponent(
            context: context,
            presentationData: presentationData,
            webpage: webpage
        ))))
    }
    if let check {
        content.append(AnyComponentWithIdentity(id: "check", component: AnyComponent(AlertCheckComponent(
            title: check.title,
            initialValue: false,
            externalState: check.state
        ))))
    }

    return AlertScreen(
        configuration: .init(allowInputInset: true),
        content: content,
        actions: [
            .init(title: presentationData.strings.Common_Cancel),
            .init(title: presentationData.strings.OpenLinkConfirmation_Open, type: .default, action: {
                open()
            }),
        ],
        updatedPresentationData: (presentationData, updatedPresentationData)
    )
}

private enum PunycodeError: Error {
    case emptyInput
    case overflow
}

private struct Punycode {
    private static let base = 36
    private static let tmin = 1
    private static let tmax = 26
    private static let skew = 38
    private static let damp = 700
    private static let initialBias = 72
    private static let initialN: UInt32 = 128
    private static let delimiter: Character = "-"

    /// Encodes a single DNS label to punycode WITHOUT "xn--" prefix.
    static func encodeLabel(_ input: String) throws -> String {
        guard !input.isEmpty else { throw PunycodeError.emptyInput }

        let scalars: [UInt32] = input.unicodeScalars.map { $0.value }
        var output = ""

        var b = 0
        for cp in scalars where cp < 0x80 {
            output.unicodeScalars.append(UnicodeScalar(cp)!)
            b += 1
        }

        var h = b
        if b > 0 && h < scalars.count { output.append(delimiter) }

        var n = initialN
        var delta: UInt32 = 0
        var bias = initialBias

        func checkedAdd(_ a: UInt32, _ b: UInt32) throws -> UInt32 {
            let (res, overflow) = a.addingReportingOverflow(b)
            if overflow { throw PunycodeError.overflow }
            return res
        }
        func checkedMul(_ a: UInt32, _ b: UInt32) throws -> UInt32 {
            let (res, overflow) = a.multipliedReportingOverflow(by: b)
            if overflow { throw PunycodeError.overflow }
            return res
        }

        while h < scalars.count {
            var m: UInt32 = UInt32.max
            for cp in scalars where cp >= n {
                if cp < m { m = cp }
            }

            let hm1 = UInt32(h + 1)
            delta = try checkedAdd(delta, try checkedMul(m - n, hm1))
            n = m

            for cp in scalars {
                if cp < n {
                    delta = try checkedAdd(delta, 1)
                } else if cp == n {
                    var q = delta
                    var k = base

                    while true {
                        let t: UInt32
                        if k <= bias { t = UInt32(tmin) }
                        else if k >= bias + tmax { t = UInt32(tmax) }
                        else { t = UInt32(k - bias) }

                        if q < t { break }

                        let digit = Int(t + (q - t) % UInt32(base - Int(t)))
                        output.append(encodeDigit(digit))
                        q = (q - t) / UInt32(base - Int(t))
                        k += base
                    }

                    output.append(encodeDigit(Int(q)))
                    bias = adapt(delta: delta, numPoints: h + 1, firstTime: h == b)
                    delta = 0
                    h += 1
                }
            }

            delta = try checkedAdd(delta, 1)
            n = try checkedAdd(n, 1)
        }

        return output
    }

    /// Encodes a domain name label-by-label; prefixes "xn--" only when needed.
    static func encodeDomain(_ domain: String) throws -> String {
        let normalized = domain.precomposedStringWithCanonicalMapping

        return try normalized
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { piece -> String in
                let label = String(piece)
                if label.isEmpty { return label } // keep empty labels as-is (rare)
                if label.unicodeScalars.allSatisfy({ $0.isASCII }) { return label }
                return "xn--" + (try encodeLabel(label))
            }
            .joined(separator: ".")
    }

    private static func encodeDigit(_ d: Int) -> Character {
        precondition((0..<36).contains(d))
        if d < 26 { return Character(UnicodeScalar(UInt8(97 + d))) }      // a-z
        else { return Character(UnicodeScalar(UInt8(48 + (d - 26)))) }    // 0-9
    }

    private static func adapt(delta: UInt32, numPoints: Int, firstTime: Bool) -> Int {
        var d = Int(delta)
        d = firstTime ? d / damp : d / 2
        d += d / numPoints

        var k = 0
        while d > ((base - tmin) * tmax) / 2 {
            d /= (base - tmin)
            k += base
        }

        return k + (base - tmin + 1) * d / (d + skew)
    }
}

private enum URLPunycodeError: Error {
    case invalidURL
}

/// Converts a full URL string to an ASCII-safe form:
/// - punycodes the host (IDN) using RFC 3492 punycode
/// - leaves scheme/port/user/pass intact
/// - lets URLComponents percent-encode path/query/fragment as needed
private func punycodedFullURLString(_ input: String) throws -> String {
    guard var comps = URLComponents(string: input) else {
        throw URLPunycodeError.invalidURL
    }

    // If there is a host, encode it. If it's a relative URL, host may be nil.
    if let host = comps.host, !host.isEmpty {
        comps.host = try Punycode.encodeDomain(host)
    }

    // URLComponents.string can be nil for some malformed component combinations
    if let out = comps.string { return out }
    throw URLPunycodeError.invalidURL
}
