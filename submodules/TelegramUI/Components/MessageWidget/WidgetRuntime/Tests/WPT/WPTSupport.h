// The WPT runner's pure parts (M1b plan, Task 17): URL resolution on the runner's origin, test discovery and page
// synthesis, the expectations format and its ratchet, the skip list, and the loader that serves the vendored tree.
// Test-only. The loader reads files under the vendored root and nothing else; nothing here links into the app.
#pragma once

#include <cstdint>
#include <functional>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "Sources/Runtime/Host.h"

namespace wr_wpt {

/// The origin every test page is served from (wptserve's default host and port).
inline constexpr std::string_view kOrigin = "http://web-platform.test:8000";

/// `ref` resolved against `base`, an absolute URL on kOrigin: an absolute URL on kOrigin, or nullopt when `ref` names
/// another origin or scheme or climbs above the root.
std::optional<std::string> resolveURL(std::string_view base, std::string_view ref);
/// The percent-decoded path of an absolute URL on kOrigin, without its query and fragment ("/dom/x.js"); nullopt for
/// another origin, or a decoded path with a "." or ".." segment.
std::optional<std::string> pathOf(std::string_view url);

/// A `.any.js` or `.window.js` file's `// META:` header (wptserve reads it up to the first line not starting "//").
struct ScriptMeta {
    std::vector<std::string> scripts;   // META: script=, in order
    std::vector<std::string> variants;  // META: variant=
    std::string title;                  // META: title=
    bool longTimeout = false;           // META: timeout=long
    bool window = true;                 // false when META: global= names neither window nor default
};
ScriptMeta parseScriptMeta(std::string_view source);

bool isTestharnessPage(std::string_view html);             // loads /resources/testharness.js
bool htmlHasLongTimeout(std::string_view html);            // <meta name=timeout content=long>
std::vector<std::string> htmlVariants(std::string_view html);  // each <meta name=variant content=…>, in order

/// wptserve's window page for the `.any.js` (`any`) or `.window.js` test at `scriptPath` ("/dom/x.any.js").
std::string synthesizePage(std::string_view scriptPath, const ScriptMeta& meta, bool any);

/// A test the runner does not run. `reason` is iframe, second-document, testdriver, server, out-of-IDL, or bug (a
/// runtime defect that crashes or hangs the runner, whose note names the ledger ruling; none may remain at the end
/// of M1b's final review).
struct SkipEntry {
    std::string test;  // with a variant ("dom/x.html?1"), or without one, covering every variant
    std::string reason;
    std::string note;
};
bool parseSkipList(std::string_view text, std::vector<SkipEntry>* out, std::string* error);
bool isSkipped(const std::vector<SkipEntry>& skips, std::string_view test);

/// One page to run.
struct Page {
    std::string test;  // the expectations key: the source path under the root, plus the variant
    std::string url;   // the page's URL on kOrigin (an .any.js/.window.js test's synthesized .html, plus the variant)
    std::string html;  // the document
    bool longTimeout = false;
};
/// Every test page under `dirs` (paths relative to `root`) that `skips` does not list, sorted by `test` in byte order.
/// Not test pages: anything under a resources/, support/, crashtests/ or tools/ directory; *-manual.* files; HTML
/// that does not load testharness.js; scripts other than .any.js and .window.js; an .any.js not run in a window.
std::vector<Page> discoverPages(const std::string& root, const std::vector<std::string>& dirs, const std::vector<SkipEntry>& skips);

/// One expectations record: a subtest's status, or (`harness`) the file's harness status.
struct Record {
    std::string test;
    bool harness = false;
    std::string subtest;
    std::string status;
};
inline constexpr std::string_view kHarness = "#harness";
std::string subtestStatusName(int status);  // testharness's Test.PASS … Test.PRECONDITION_FAILED
std::string harnessStatusName(int status);  // testharness's OK … PRECONDITION_FAILED
std::string escapeField(std::string_view);
std::string unescapeField(std::string_view);
std::string formatExpectations(std::vector<Record> records);
bool parseExpectations(std::string_view text, std::vector<Record>* out, std::string* error);
/// 2 for a pass (PASS, OK), 1 for a finished failure (FAIL, PRECONDITION_FAILED, ERROR), 0 for not finishing.
int rank(const Record&);

struct Comparison {
    std::vector<std::string> regressions;   // lower rank than expected, or expected and not reported
    std::vector<std::string> improvements;  // higher rank than expected, or new and passing
    std::vector<std::string> changes;       // another status of the same rank, or new and not passing
    bool matches() const { return regressions.empty() && improvements.empty() && changes.empty(); }
};
/// `actual` against the `expected` records whose test `inScope` admits.
Comparison compare(const std::vector<Record>& expected, const std::vector<Record>& actual,
                   const std::function<bool(std::string_view test)>& inScope);

/// The contents of a regular file (never a symlink, a directory or a device), or nullopt.
std::optional<std::string> readFile(const std::string& path);

/// A wr::ScriptLoader over the vendored tree: same-origin URLs map to regular files under `root`, in what
/// //third-party/wpt:TestFiles declares (resources/, common/, dom/, html/ and LICENSE.md); the page's
/// /resources/testharnessreport.js is the runner's shim. Anything else is refused and remembered.
class WPTLoader final : public wr::ScriptLoader {
public:
    WPTLoader(std::string root, std::string reportShim);
    /// Relative `src` values resolve against this URL (M1b has no URL parser: the runtime passes `src` as written).
    void setPageURL(std::string url) { m_pageURL = std::move(url); }
    std::optional<wr::ScriptSource> load(std::string_view url) override;
    const std::vector<std::string>& refused() const { return m_refused; }

private:
    std::string m_root;
    std::string m_canonicalRoot;
    std::string m_reportShim;
    std::string m_pageURL;
    std::vector<std::string> m_refused;
};

} // namespace wr_wpt
