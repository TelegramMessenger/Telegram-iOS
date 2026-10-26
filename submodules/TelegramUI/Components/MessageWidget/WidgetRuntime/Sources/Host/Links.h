// Links (SDK v1 §2.5; V2a plan, Task 5): the URL rules and their normalisation (widget-sandbox v0.1.0
// packages/core/src/shared/sdk-policy.ts checkLink), TelegramWidget's two link methods, and the route an `<a href>` tap
// or window.open takes (packages/core/src/sandbox/globals.ts followLink). A checked call reaches the host only while a
// trusted pointer press dispatches, one call per press (HostState::consumeActivation); any other is dropped with the
// diagnostic activation-blocked.
#pragma once

#include <optional>
#include <string>

#include "Sources/Support/Values.h"

namespace wr {

enum class LinkMethod : uint8_t { OpenLink, OpenTelegramLink };

/// MAX_LINK_LENGTH: the URL's UTF-8 bytes as given, and the normalised URL's characters.
inline constexpr size_t kMaxLinkLength = 256;
/// activation-blocked and navigation-blocked are each reported at most this often per widget.
inline constexpr uint32_t kMaxLinkDiagnostics = 20;

/// checkLink: an absolute https: URL without user name or password, an ASCII host of LDH labels, an optional port, at
/// most kMaxLinkLength UTF-8 bytes as given and characters once non-ASCII after the host is percent-encoded as UTF-8;
/// openTelegramLink takes only t.me, telegram.me and telegram.dog and their subdomains, openLink every other host.
/// Scheme and host come out lowercase (A–Z only), the rest as given; nullopt when a rule is broken.
std::optional<std::string> checkLink(LinkMethod method, const String& url);

/// TelegramWidget.openLink and openTelegramLink: anything checkLink refuses (a non-string too) is a TypeError; a valid
/// call is posted when the press allows it, else dropped with activation-blocked.
void openLinkFromWidget(JSContext* ctx, LinkMethod method, const std::optional<Value>& url);

/// followLink: a URL the widget did not open through the SDK. Trimmed; javascript: is ignored; a Telegram host goes to
/// openTelegramLink, another valid one to openLink (as a widget call that passed its checks); anything else is ignored
/// with navigation-blocked. Never throws a TypeError.
void followLink(JSContext* ctx, const String& url);

/// A link's activation behaviour (`<a href>`): an empty href or a fragment does nothing, any other is followLink.
void followAnchor(JSContext* ctx, const String& href);

} // namespace wr
