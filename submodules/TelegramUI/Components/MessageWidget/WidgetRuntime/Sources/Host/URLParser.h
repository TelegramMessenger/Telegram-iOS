// The URL Standard's URL record, basic URL parser and serializer (V5a plan, Task 7). No state override (URL's setters
// splice and re-parse, Sources/Host/URL.cpp). A domain goes through UTS 46 from the system ICU (V5b, domainToASCII). No
// JS: its strings are transient, bounded by kMaxURLLength.
#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace wr::url {

/// Inputs longer than this many UTF-16 code units fail to parse (Ruling; browsers cap theirs near 2 MiB): every string
/// the parser builds is then at most 9 bytes per unit.
inline constexpr size_t kMaxURLLength = size_t(1) << 20;

struct Record {
    std::string scheme;
    std::string username;
    std::string password;
    std::optional<std::string> host;
    std::optional<uint16_t> port;
    /// An opaque path ("mailto:x@y") instead of segments.
    bool opaquePath = false;
    std::string opaque;
    std::vector<std::string> path;
    std::optional<std::string> query;
    std::optional<std::string> fragment;

    bool special() const;
    /// The URL serializer.
    std::string serialize(bool excludeFragment = false) const;
    /// The origin's serialization: "scheme://host[:port]" for http, https, ws, wss and ftp, else "null".
    std::string origin() const;
    /// The URL path serializer.
    std::string pathname() const;
};

bool isSpecialScheme(std::string_view scheme);
std::optional<uint16_t> defaultPort(std::string_view scheme);

/// The URL Standard's "domain to ASCII" with beStrict false, over a percent-decoded domain's bytes: an ASCII domain is
/// ASCII-lowercased (as WPT's data has it, "xn--" labels included); any other goes through UTS 46 (the system ICU) with
/// CheckBidi and CheckJoiners, non-transitional, without UseSTD3ASCIIRules, CheckHyphens or VerifyDnsLength. nullopt
/// is failure.
std::optional<std::string> domainToASCII(const std::string& domain);

/// The basic URL parser over scalar-value code units (a USVString's), against `base` when given. nullopt is failure.
std::optional<Record> parse(const std::u16string& input, const Record* base);

enum class EncodeSet { C0Control, Fragment, Query, SpecialQuery, Path, Userinfo };
/// UTF-8 percent-encodes `codePoint` with `set` onto `out`.
void percentEncode(char32_t codePoint, EncodeSet set, std::string& out);
/// The code points of `input` (lone surrogates as U+FFFD).
std::u32string codePoints(const std::u16string& input);

} // namespace wr::url
