// data: URLs (M1c plan, Task 3): WHATWG Fetch's data: URL processor (https://fetch.spec.whatwg.org/#data-url-processor),
// which decides what WidgetContainer can load: a data: URL whose type is image/* and nothing else.
#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace wr {

struct DataUrl {
    /// The MIME type's essence, `type/subtype`, ASCII lowercase; `text/plain` when the URL's type is empty or does
    /// not parse. Parameters (`charset`, ...) are not kept.
    std::string mimeType;
    std::vector<uint8_t> bytes;
};

/// `url` processed as the URL parser and Fetch's data: URL processor do:
/// 1. leading and trailing C0 controls and spaces are stripped, and every ASCII tab and newline removed;
/// 2. the scheme must be `data:`, ASCII case-insensitively;
/// 3. the fragment is dropped (Fetch serializes the URL without it);
/// 4. the type is the text before the first `,`, trimmed of ASCII whitespace; a final `;base64` (case-insensitive,
///    spaces allowed before `base64`) selects forgiving-base64, which drops ASCII whitespace first, after the body
///    is percent-decoded.
/// nullopt when the scheme is not data:, there is no `,`, or the base64 is invalid. A hierarchical `data:/...` URL is
/// not normalised as the URL parser would; its type is text/plain either way.
std::optional<DataUrl> parseDataUrl(std::string_view url);

} // namespace wr
