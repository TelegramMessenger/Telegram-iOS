# WEB proxy carrier (`tg://webproxy`)

A third proxy kind beside SOCKS5 and MTProxy. MtProtoKit's obfuscated2 transform runs unchanged; only where the
transformed TCP stream goes changes. Each MTProto connection becomes a logical stream multiplexed over a hidden
`WKWebView` that speaks HTTPS/WSS to a `tproxy-server` relay, which turns each stream back into one TCP connection to a
stock MTProxy, so the relay cannot pick a destination or decrypt anything. The wire contract is upstream and
client-neutral ([`PROTOCOL.md`](https://github.com/telegramdesktop/tproxy-server/blob/master/PROTOCOL.md), with
`IOS.md`, `BASE_PATH.md` and `HARDENING.md` beside it); the client half is `submodules/WebProxyTransport` plus the
`ProxySettings`/`SettingsUI`/`UrlHandling` wiring.

The non-obvious parts:

- **The loopback address never leaves MtProtoKit.** `MTSocksProxySettings.webProxy` is the whole hook:
  `MTTcpConnection` substitutes `127.0.0.1:443` at dial time while `ip` keeps the **public** hostname, so proxy
  identity, sponsored-channel attribution and `ProxyServerPreviewScreen`'s "wait until the account reports online
  through this address" check keep working, and the loopback endpoint is never displayed or shared.
- **One process-wide carrier**, `WebProxyTransport.shared`, runs exactly while a configuration is present *and* someone
  holds demand (`setCarrierDemand(_:wanted:)`, idempotent per token). Demand rides `shouldKeepConnection` (the app's
  foreground/background/service-task machinery), which meets IOS.md's foreground-only lifecycle without a background
  mode or a timer of our own. `Network.swift` refuses the carrier outright when the main bundle ends in `.appex`.
- **The web view must be in a real view hierarchy** or WebKit throttles off-screen work and the long poll stalls with
  no error. The module cannot import UIKit (TelegramCore depends on it and is shared with Telegram-Mac), so its
  `WebProxyCarrierViewHost` is implemented by `TelegramUI/Sources/WebProxyCarrierWindowHost.swift` as a 1pt,
  noninteractive, `alpha = 0.01` view at the bottom of the root container. Zero alpha is *not* equivalent.
- **Base-path relays.** `.web(secret:path:)` encodes as `_t = 3` only when the path is non-empty; `_t = 2` stays
  byte-identical for existing root records. The bridge capability binds the path (context `…-v1\nH` at the root,
  `…-v2\nH\nP` under a prefix), so one capability authenticates nothing at another prefix. The path is
  **case-sensitive** and never folded, unlike the host. The editor has one "server" field holding the whole
  `host/base-path` address (`canonicalWebProxyAddress`); the list row drops the port for a WEB entry (443 is implied).
- **The `0x70` marked secret.** A link that carries a base path *must* encode its secret as unpadded base64url of
  `0x70 || secret`; an unmarked secret there is **rejected**, so no link exists that a client without base-path
  support would silently accept as a pathless proxy on an empty host. Never `0xDD`: an older parser reads that as an
  ordinary padded secret. Enforced in `parseWebProxyLinkComponents`, which every link entry point (QR, pasteboard,
  `tg://`/`t.me` handling) goes through; hand entry in the editor stays lenient on purpose, because the hazard is
  specific to a shared link.
- **The carrier's `WKWebView` is hardened on its own and must never share anything** with Mini Apps, payments, 3-D
  Secure, Instant View embeds or the location picker: its own configuration, nonpersistent store and user-content
  controller per carrier lifetime. A different operator controls the proxy document, so the client imposes an
  independent meta CSP rather than trusting the response's own. `WebProxyWebViewHardening` installs **two**
  document-start scripts in order: the execution profile, then the bridge shim. The profile goes into **every frame**:
  under its own CSP a page can still append a src-less `about:blank` iframe (`frame-src 'none'` does not stop it, the
  initial about:blank being no fetch), and with a main-frame-only profile that child's `navigator.geolocation`,
  `Worker` and `BroadcastChannel` are pristine (`WebProxyFrameIsolationTests`). The shim stays main-frame-only because
  it is the half that reaches native, and refuses to expose `TelegramWebProxy` unless the profile's flag says it is in
  place. Construction fails closed if the scripts did not install, so a carrier without the policy never navigates.
- **The meta CSP creates `document.head` when the parser has not reached it yet.** WebKit honours a `<meta>` policy
  only inside `document.head`, defined as the *first* head child of `<html>`, so the injected head becoming that first
  head is load-bearing; the parser's own head then lands after it as a second head element.
- **Geolocation has no public refusal below iOS 27.** There every request reaches `WKWebGeolocationPolicyDecider`
  through `PageClientImpl` (the `completionHandler(false)` at the end of
  `WebPageProxy::requestGeolocationPermissionForFrame` is unreachable on iOS), which presents a `UIAlertController` on
  the view's **full-screen presentation context**, needs no user gesture, and auto-allows an origin after
  `kGeolocationChallengeThreshold` (2) grants recorded in `GeolocationSitesV2.plist`. The public
  `requestGeolocationPermissionFor` delegate (iOS 27+) denies it; below that the all-frames `navigator.geolocation`
  shim is the block, and the private SPI is deliberately not used. Do not describe the shims as the boundary anywhere
  else — here they are it.
- Calls stay SOCKS5-only (a WEB entry is never offered). `ProxyServersStatuses` never pings an inactive WEB row, which
  would read "checking…" forever: the row shows "not tested", and only the active one follows the real account
  connection state.
