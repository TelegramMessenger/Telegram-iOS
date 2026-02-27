import Foundation
import Display
import SwiftSignalKit
import Postbox
import AccountContext
import OverlayStatusController
import UrlWhitelist
import TelegramPresentationData
import AlertComponent
import UrlHandling

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
    
    if let parsedUrl = parseInternalUrl(sharedContext: context.sharedContext, context: context, query: url) {
        if case .proxy = parsedUrl {
            concealed = true
        }
    }
    
    if concealed && !skipConcealedAlert {
        var rawDisplayUrl: String = parsedString
        let maxLength = 180
        if rawDisplayUrl.count > maxLength {
            rawDisplayUrl = String(rawDisplayUrl[..<rawDisplayUrl.index(rawDisplayUrl.startIndex, offsetBy: maxLength - 2)]) + "..."
        }
        
        var displayUrl = rawDisplayUrl
        displayUrl = displayUrl.replacingOccurrences(of: "\u{202e}", with: "")
        displayUrl = (try? punycodedFullURLString(displayUrl)) ?? displayUrl
        
        let disposable = MetaDisposable()
        
        let alertController = textAlertController(context: context, forceTheme: forceDark ? presentationData.theme : nil, title: nil, text: presentationData.strings.Generic_OpenHiddenLinkAlert(displayUrl).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
            disposable.set(openImpl())
        })])
        if let alertController = alertController as? AlertScreen {
            alertController.dismissed = {  _ in
                alertDisplayUpdated?(nil)
            }
        }
        present(alertController)
        alertDisplayUpdated?(alertController)
        return disposable
    } else {
        return openImpl()
    }
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
