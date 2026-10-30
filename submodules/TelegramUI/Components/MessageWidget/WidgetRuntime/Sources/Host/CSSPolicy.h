// Profile 1's CSS and URL rules as one pure policy (V4 plan, Task 2): what the renderer's copy of a widget keeps of a
// declaration, a value, a selector, an @media prelude and an @supports condition, and which URLs it lets through — the
// rules of widget-sandbox v0.1.0's validator (css-sanitizer.ts, url-policy.ts, css-supports.ts), read from the profile's
// tables (Profile.h). It reads only its arguments and the tables: it never throws or interns a name (litehtml::_id),
// so the litehtml container hooks (Task 3b) can call it inside a parse, and litehtml's caches, which key on text, stay
// right. CSS.supports (CSSSupports.h) wraps the same verdicts.
#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <utility>

#include <litehtml/css_tokenizer.h>

namespace wr::css::policy {

/// Keep: as written. Augment: kept, with something completed or resolved that the author wrote (a ui-* family's
/// fallback appended, light-dark() and `color-scheme: light dark` resolved by the renderer, :disabled and :enabled
/// written as attribute selectors). Rewrite: changed (sticky → relative, overflow → hidden, a filter list pruned, named
/// families removed). Drop: removed.
enum class Verdict : uint8_t { Keep, Augment, Rewrite, Drop };

/// CSS.supports and @supports: true exactly when the profile keeps the declaration (profile-v1.md D23).
inline bool supported(Verdict v) {
    return v == Verdict::Keep || v == Verdict::Augment;
}

struct Judged {
    Verdict verdict = Verdict::Drop;
    /// What the renderer gets (the input's tokens with the rewrite applied; empty for Drop).
    litehtml::css_token_vector value;
};

/// A declaration (RB §4.1–§4.9): `name` ASCII-lowercased (a custom property keeps its case), `value` its component
/// values with or without whitespace tokens. A rewrite edits the input's tokens in place: a replaced identifier keeps
/// its place, a removed item goes with the whitespace token before it, a regenerated family list is `a,b`.
Judged declaration(std::string_view name, std::span<const litehtml::css_token> value);
/// RB §4.5 alone (units, functions, url(), strict attr()), after env()'s rewrite as in a declaration: an SVG attribute
/// whose value is CSS.
Judged value(std::span<const litehtml::css_token> value);
/// One complex selector of a list (RB §5): Drop when it names a pseudo-class or pseudo-element outside the profile, or
/// `&`, anywhere (inside :not() and :is() too); Augment when :disabled or :enabled was rewritten. A malformed one (a
/// colon followed by no name) is Keep: litehtml's strict parse decides it.
Judged selector(std::span<const litehtml::css_token> complexSelector);
/// An at-rule the profile keeps (media, supports, keyframes, -webkit-keyframes).
bool atRuleKept(std::string_view loweredName);
/// An @media prelude or matchMedia query whose every query names only profile media types and features (RB §6.2;
/// plan OP2: a range's dimension is a value, not a feature). Empty is in.
bool mediaQueryInProfile(std::span<const litehtml::css_token> prelude);
/// CSS Conditional 4's <supports-condition> under the profile (RB §6.3; plan OP3: mixing and/or without parentheses is
/// invalid). Invalid is false.
bool supportsCondition(std::span<const litehtml::css_token> condition);
/// A parenthesized block's contents as @supports reads them: a condition, else a declaration, else false (CSSOM's
/// fallback for CSS.supports(text), the text taken as in parentheses).
bool supportsParenthesized(std::span<const litehtml::css_token> inner);

/// RB §3.1: every tab, line feed and carriage return removed, then U+0000–U+0020 trimmed from both ends.
std::string normalizedUrl(std::string_view url);
/// RB §3.2 kind "image": a well-formed #fragment, or a data: URL of a profile image type (CSS url()).
bool urlKept(std::string_view url);
/// An <img src> the renderer may load: urlKept, and not a fragment (RB §2.4); imageSource(src) is Kept.
bool imageSourceKept(std::string_view src);
/// widget-sandbox v0.3.0 (url-policy.ts MAX_IMAGE_PIXELS, under every policy): the most pixels a data: image may claim.
inline constexpr uint64_t kMaxDataImagePixels = uint64_t(1024) * 1024;
/// What an image URL is to the renderer and the DOM alike (url-policy.ts checkUrl): Kept; Refused, the 48 px placeholder
/// (not a data: URL of the profile's image types, a fragment, or one whose bytes claim more than kMaxDataImagePixels);
/// Broken, bytes of none of the profile's formats, which no decoder takes (the browser picks the decoder by the bytes,
/// not the declared type): an `error`.
enum class ImageSource : uint8_t { Kept, Refused, Broken };
ImageSource imageSource(std::string_view src);
/// The size a decoder would give a data: image, by its signature (url-policy.ts dataImageSize: PNG's IHDR, GIF's screen
/// grown to its first frame, WebP's first chunk, JPEG's first frame header; the body read as fetch decodes it, a header
/// looked for within 64 KB and a bounded number of steps); nullopt for bytes of none of the profile's formats.
std::optional<std::pair<uint32_t, uint32_t>> dataImageSize(std::string_view url);
/// The normalized `href` when it is a well-formed fragment (`^#[^\s"'()\\<>]*$`), else nullopt (RB §2.4).
std::optional<std::string> fragmentHref(std::string_view href);
/// RB §4.7 over a computed family list (`create_font`'s backstop): the reduced list, or `family` when it is kept.
std::string reduceFontFamilyText(std::string_view family);

} // namespace wr::css::policy
