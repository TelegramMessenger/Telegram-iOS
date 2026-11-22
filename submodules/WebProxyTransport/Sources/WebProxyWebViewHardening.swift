import Foundation
import WebKit

/// The document-start execution profile IOS.md requires of the WEB carrier's web view.
///
/// A different operator controls the proxy document and its response headers, so the
/// response's own CSP is not ours to rely on: the carrier imposes an independent policy
/// of its own before the provider's script runs. The shims below are surface reduction —
/// WebKit's CSP and the native delegates are the security boundary.
///
/// None of this may be retrofitted onto Telegram's other web views (Mini Apps, payments,
/// 3-D Secure, Instant View embeds, the location picker). The carrier gets its own
/// `WKWebViewConfiguration`, `WKProcessPool` and nonpersistent data store for its lifetime.
enum WebProxyWebViewHardening {
    /// PROTOCOL.md's "hardened WebView execution profile", written as a policy the client
    /// applies itself. `script-src 'unsafe-inline'` is what lets the bridge's own
    /// nonce-bearing inline script run: the response CSP separately requires that nonce,
    /// and a document must satisfy every policy that applies to it.
    ///
    /// Never add `'unsafe-eval'`, `blob:`, `data:`, a wildcard host, an alternate port or
    /// an HTTP source. `frame-ancestors`, `report-uri` and `sandbox` are deliberately
    /// absent: a `<meta>` policy ignores them.
    static func contentSecurityPolicy(host: String) -> String {
        return [
            "default-src 'none'",
            "base-uri 'none'",
            "child-src 'none'",
            "connect-src https://\(host) wss://\(host)",
            "font-src 'none'",
            "form-action 'none'",
            "frame-src 'none'",
            "img-src 'none'",
            "manifest-src 'none'",
            "media-src 'none'",
            "object-src 'none'",
            "script-src 'unsafe-inline'",
            "style-src 'none'",
            "worker-src 'none'"
        ].joined(separator: "; ")
    }

    /// Applies the configuration-level half of the profile: no persistence, no media
    /// autoplay, no AirPlay or picture-in-picture, no automatic windows.
    ///
    /// The view is also kept noninteractive, but that is `UIView` state the host sets when
    /// it attaches the view — this module must not import UIKit (see
    /// `WebProxyCarrierViewHost`).
    static func apply(to configuration: WKWebViewConfiguration) {
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.allowsAirPlayForMediaPlayback = false
        if #available(macOS 12.3, iOS 15.4, *) {
            configuration.preferences.isElementFullscreenEnabled = false
        }
        #if os(iOS)
        configuration.allowsPictureInPictureMediaPlayback = false
        // Inline, NOT false. `false` routes HTML5 video to the native full-screen
        // controller - the one way a hidden carrier could put the provider's document in
        // front of the user. Playback should be impossible here (`media-src 'none'`, a
        // required user action, and a view that takes no touches), so this is the
        // backstop for all three failing at once: keep anything that does play inside the
        // one-point view.
        configuration.allowsInlineMediaPlayback = true
        #endif
    }

    /// The document-start script, injected into EVERY frame (see the carrier's note): each
    /// frame is its own realm, so a shim installed only in the main one is bypassed by a
    /// src-less `about:blank` iframe.
    ///
    /// `flag` is a random property name the bridge shim reads to confirm that the policy is
    /// actually in place before it exposes itself to the page.
    static func script(host: String, flag: String) -> String {
        return """
        (() => {
          'use strict';
          const define = (target, name, descriptor) => {
            if (!target) return;
            // A non-configurable own property cannot be shadowed. Failing one shim must not
            // abort the rest, and none of them is the security boundary.
            try { Object.defineProperty(target, name, descriptor); } catch (error) {}
          };
          const constant = (target, name, value) => define(target, name, {value, configurable: false, writable: false, enumerable: false});
          const unavailable = (target, name) => constant(target, name, undefined);

          // At `.atDocumentStart` the document element exists but the parser has usually
          // not reached `<head>` yet, so one is created here. WebKit only honours a
          // `<meta>` policy that is a descendant of `document.head` - the FIRST head child
          // of `<html>` - and the one created here is exactly that; the parser's own head
          // then lands after it as a second head element. That is deliberate and safe for
          // this page: the reference bridge carries no meta the document depends on, and
          // its own policy arrives as a response header rather than as markup.
          let installed = false;
          try {
            const root = document.documentElement || document.appendChild(document.createElement('html'));
            const head = document.head || root.insertBefore(document.createElement('head'), root.firstChild);
            const policy = document.createElement('meta');
            policy.setAttribute('http-equiv', 'Content-Security-Policy');
            policy.setAttribute('content', \(javaScriptString(contentSecurityPolicy(host: host))));
            head.insertBefore(policy, head.firstChild);
            const prefetch = document.createElement('meta');
            prefetch.setAttribute('http-equiv', 'x-dns-prefetch-control');
            prefetch.setAttribute('content', 'off');
            head.insertBefore(prefetch, policy.nextSibling);
            installed = true;
          } catch (error) {}

          // Storage. The nonpersistent store already keeps this off disk; removing the DOM
          // surface keeps a provider document from creating same-origin state at all.
          for (const name of ['localStorage', 'sessionStorage', 'indexedDB', 'webkitIndexedDB', 'caches']) unavailable(globalThis, name);
          define(document, 'cookie', {get: () => '', set: () => {}, configurable: false, enumerable: false});

          // Workers and cross-context channels. The bridge uses none of them, and a worker
          // would escape the main-frame-only script-message boundary.
          for (const name of ['Worker', 'SharedWorker', 'BroadcastChannel']) unavailable(globalThis, name);
          unavailable(globalThis.navigator, 'serviceWorker');

          // Audio, capture, clipboard and device APIs. WebRTC is included as surface
          // reduction only: PROTOCOL.md does not claim it is reliably disabled everywhere.
          for (const name of ['Audio', 'AudioContext', 'webkitAudioContext', 'OfflineAudioContext', 'webkitOfflineAudioContext', 'RTCPeerConnection', 'webkitRTCPeerConnection']) unavailable(globalThis, name);
          for (const name of ['clipboard', 'mediaDevices', 'geolocation', 'bluetooth', 'usb', 'hid', 'serial', 'credentials', 'getUserMedia', 'webkitGetUserMedia']) unavailable(globalThis.navigator, name);

          // Windows and dialogs. The native delegates refuse these as well; answering them
          // here keeps a page from blocking on a call that would never come back.
          constant(globalThis, 'open', () => null);
          constant(globalThis, 'print', () => {});
          constant(globalThis, 'alert', () => {});
          constant(globalThis, 'confirm', () => false);
          constant(globalThis, 'prompt', () => null);

          constant(globalThis, \(javaScriptString(flag)), installed);
        })();
        """
    }

    /// A JSON-encoded string literal, so nothing in `value` needs hand-escaping.
    static func javaScriptString(_ value: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [value])
        let array = String(data: data, encoding: .utf8)!
        return String(array.dropFirst().dropLast())
    }
}
