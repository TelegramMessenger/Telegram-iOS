// The pure CSS policy (V4 plan, Task 2): profile 1's rules for a declaration, a value, a selector, an @media prelude,
// an @supports condition and a URL, as the reference validator applies them (widget-sandbox v0.1.0 css-sanitizer.ts,
// url-policy.ts, css-supports.ts). Every rule here is what the renderer's copy of a widget gets (Task 3b's hooks) and
// what CSS.supports answers (Keep and Augment only).
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <functional>
#include <string>
#include <vector>

#include <litehtml/css_parser.h>
#include <litehtml/string_id.h>

#include "Sources/Host/CSSPolicy.h"
#include "Tests/HostHarness.h"

namespace policy = wr::css::policy;
using policy::Verdict;

namespace {

litehtml::css_token_vector tokens(std::string_view text) {
    return litehtml::normalize(std::string(text), litehtml::f_componentize);
}

const char* verdictName(Verdict v) {
    switch (v) {
    case Verdict::Keep:
        return "Keep";
    case Verdict::Augment:
        return "Augment";
    case Verdict::Rewrite:
        return "Rewrite";
    case Verdict::Drop:
        return "Drop";
    }
    return "?";
}

std::string trimmed(const std::string& s) {
    const size_t first = s.find_first_not_of(" \t\n");
    const size_t last = s.find_last_not_of(" \t\n");
    return first == std::string::npos ? std::string() : s.substr(first, last - first + 1);
}

std::string shown(const policy::Judged& judged) {
    return std::string(verdictName(judged.verdict)) + "|" +
           (judged.verdict == Verdict::Drop ? std::string() : trimmed(litehtml::get_repr(judged.value)));
}

struct Row {
    const char* name;
    const char* value;
    const char* expected;
};

/// The rows whose judgement differs from `expected`, joined; "" when every row holds.
std::string declarationMismatches(const std::vector<Row>& rows) {
    std::string out;
    for (const Row& row : rows) {
        const litehtml::css_token_vector value = tokens(row.value);
        const std::string got = shown(policy::declaration(row.name, value));
        if (got != row.expected) {
            out += std::string(" [") + row.name + ": " + row.value + " → " + got + ", want " + row.expected + "]";
        }
    }
    return out;
}

struct Pair {
    const char* input;
    const char* expected;
};

} // namespace

WR_TEST(testTheDeclarationRules) {
    CHECK_EQ(declarationMismatches({
                 {"position", "sticky", "Rewrite|relative"},
                 {"position", "-webkit-sticky", "Rewrite|relative"},
                 {"overflow", "hidden scroll", "Rewrite|hidden hidden"},
                 {"overflow", "clip auto", "Rewrite|clip hidden"},
                 {"overflow-y", "auto", "Rewrite|hidden"},
                 {"overflow", "var(--o)", "Keep|var(--o)"},
                 {"color", "color-mix(in srgb, red, blue)", "Drop|"},
                 {"color", "oklch(1 0 0)", "Drop|"},
                 {"color", "hwb(0 0% 0%)", "Drop|"},
                 {"background-image", "url(https://x/a.png)", "Drop|"},
                 {"background", "url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==)", "Keep|url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==)"},
                 // widget-sandbox v0.3.0: bytes of no image format behind an image type are no image.
                 {"background", "url(data:image/png;base64,AA)", "Drop|"},
                 {"background", "url(data:image/svg+xml,x)", "Drop|"},
                 {"background-image", "URL( http://x )", "Drop|"},
                 {"background-image", "url(\\68 ttp://x)", "Drop|"},
                 {"cursor", "url(#c)", "Keep|url(#c)"},
                 {"font-family", "\"Courier New\", \"Courier\"", "Rewrite|system-ui"},
                 {"font-family", "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, sans-serif", "Rewrite|system-ui,sans-serif"},
                 {"font-family", "-apple-system, system-ui, sans-serif", "Rewrite|system-ui,sans-serif"},
                 {"font-family", "\"Inter\"", "Rewrite|system-ui"},
                 {"font-family", "\"serif\"", "Rewrite|system-ui"},
                 {"font-family", "ui-monospace, SFMono-Regular, Menlo", "Rewrite|ui-monospace,monospace"},
                 {"font-family", "ui-monospace", "Augment|ui-monospace,monospace"},
                 {"font-family", "Serif, monospace", "Keep|Serif, monospace"},
                 {"font-family", "var(--f), sans-serif", "Keep|var(--f), sans-serif"},
                 {"font-family", "inherit", "Keep|inherit"},
                 {"font", "600 14px/1.2 -apple-system, sans-serif", "Rewrite|600 14px/1.2 system-ui,sans-serif"},
                 {"font", "caption", "Keep|caption"},
                 {"font", "12px", "Drop|"},
                 {"text-shadow", "0 0 1px red", "Drop|"},
                 {"user-select", "text", "Keep|text"},   // in profile 1 since widget-sandbox v0.1.1
                 {"-webkit-user-select", "none", "Keep|none"},
                 {"user-select", "all", "Drop|"},          // outside css.values["user-select"]
                 {"-webkit-user-select", "contain", "Drop|"},
                 {"user-select", "text auto", "Drop|"},
                 {"user-select", "var(--s)", "Keep|var(--s)"},
                 {"clip-path", "circle(50%)", "Drop|"},
                 {"filter", "blur(2px) grayscale(1)", "Rewrite|blur(2px)"},
                 {"filter", "blur(2px) sepia(1) brightness(2)", "Rewrite|blur(2px) brightness(2)"},
                 {"filter", "grayscale(1)", "Drop|"},
                 {"filter", "url(#f)", "Drop|"},
                 {"filter", "none", "Keep|none"},
                 {"filter", "var(--f)", "Keep|var(--f)"},
                 {"filter", "env(x)", "Drop|"},
                 {"transform", "rotateY(60deg)", "Drop|"},
                 {"transform", "perspective(100px) rotateY(55deg)", "Drop|"},
                 {"perspective", "80px", "Drop|"},
                 {"transform-style", "preserve-3d", "Drop|"},
                 {"rotate", "z 45deg", "Drop|"},
                 {"rotate", "45deg", "Keep|45deg"},
                 {"translate", "1px 2px 3px", "Drop|"},
                 {"height", "100vh", "Drop|"},
                 {"height", "0vh", "Drop|"},
                 {"width", "50cqw", "Drop|"},
                 {"width", "env(safe-area-inset-left)", "Augment|var(--tg-content-safe-area-inset-left)"},
                 // widget-sandbox v0.4.0 (sdk-v1 §2.17): a safe-area inset is the root variable, its fallback kept; another
                 // name is its fallback, or the declaration is dropped.
                 {"width", "env(safe-area-inset-bottom, 77px)", "Augment|var(--tg-content-safe-area-inset-bottom, 77px)"},
                 {"width", "calc(1px + env(safe-area-inset-top))", "Augment|calc(1px + var(--tg-content-safe-area-inset-top))"},
                 {"width", "env(keyboard-inset-height, 13px)", "Rewrite|13px"},
                 {"width", "env(keyboard-inset-height)", "Drop|"},
                 // An empty fallback: kept for a safe-area inset (var() takes one), dropped for another name (resolveEnv).
                 {"width", "env(safe-area-inset-bottom,)", "Augment|var(--tg-content-safe-area-inset-bottom,)"},
                 {"width", "env(keyboard-inset-height,)", "Drop|"},
                 {"width", "env(SAFE-AREA-INSET-TOP)", "Drop|"},
                 {"--s", "env(safe-area-inset-bottom)", "Augment|var(--tg-content-safe-area-inset-bottom)"},
                 {"width", "round(10px, 3px)", "Drop|"},
                 {"margin-inline-start", "20px", "Drop|"},
                 {"content", "attr(class)", "Drop|"},
                 {"content", "attr(data-x)", "Keep|attr(data-x)"},
                 {"content", "attr(title)", "Keep|attr(title)"},
                 {"content", "attr(data-x type(<length>))", "Drop|"},
                 {"--x", "attr(id)", "Drop|"},
                 {"behavior", "url(x.htc)", "Drop|"},
                 {"color-scheme", "light dark", "Augment|light dark"},
                 {"color", "light-dark(#fff, #000)", "Augment|light-dark(#fff, #000)"},
                 {"color", "light-dark(url(https://x), red)", "Drop|"},
                 {"display", "flow-root", "Drop|"},
                 {"display", "inline flex", "Drop|"},
                 {"display", "var(--d)", "Keep|var(--d)"},
                 {"display", "grid", "Keep|grid"},
                 {"--h", "100vh", "Drop|"},
                 {"--c", "oklch(1 0 0)", "Drop|"},
                 {"--y", "12px", "Keep|12px"},
                 {"--t", "rotateY(1deg)", "Drop|"},
                 {"margin", "inherit", "Keep|inherit"},
                 {"fill", "url(#g)", "Keep|url(#g)"},
                 {"background-clip", "text", "Drop|"},
                 // The core drops -lh-anim; WidgetContainer passes it before asking (Task 3b).
                 {"-lh-anim", "1", "Drop|"},
             }),
             std::string(""));
}

/// The hook sees a value with its whitespace removed (litehtml's style::add); a rewrite then makes no whitespace either.
WR_TEST(testAWhitespaceFreeValueStaysWhitespaceFree) {
    litehtml::css_token_vector value = tokens("blur(2px) sepia(1) brightness(2)");
    litehtml::remove_whitespace(value);
    const policy::Judged judged = policy::declaration("filter", value);
    CHECK(judged.verdict == Verdict::Rewrite);
    CHECK_EQ(litehtml::get_repr(judged.value), std::string("blur(2px)brightness(2)"));
    value = tokens("hidden scroll");
    litehtml::remove_whitespace(value);
    CHECK_EQ(litehtml::get_repr(policy::declaration("overflow", value).value), std::string("hiddenhidden"));
    CHECK(policy::declaration("overflow", value).value.size() == 2);
}

WR_TEST(testTheValueRules) {
    const Pair rows[] = {
        {"url(#g)", "Keep"}, {"url(https://x#g)", "Drop"}, {"oklch(1 0 0)", "Drop"},
        {"2px", "Keep"},     {"scroll", "Keep"},           {"attr(class)", "Drop"},
    };
    std::string out;
    for (const Pair& row : rows) {
        const std::string got = verdictName(policy::value(tokens(row.input)).verdict);
        if (got != row.expected) {
            out += std::string(" [") + row.input + " → " + got + "]";
        }
    }
    CHECK_EQ(out, std::string(""));
}

WR_TEST(testTheSelectorRules) {
    const Pair rows[] = {
        {"p", "Keep|p"},
        {":host", "Drop|"},
        {"a:not(:focus)", "Drop|"},
        {":is(a, :focus)", "Drop|"},
        {":before", "Keep|:before"},
        {":first-letter", "Drop|"},
        {"::BEFORE", "Keep|::BEFORE"},
        {"::marker", "Drop|"},
        {".a:has(.b)", "Drop|"},
        {"& .a", "Drop|"},
        {"button:disabled", "Augment|button[disabled]"},
        {"a:enabled", "Augment|a:not([disabled])"},
        {":lang(en)", "Keep|:lang(en)"},
        {":root", "Keep|:root"},
        {".d:", "Keep|.d:"},
        {"li:nth-child(2n+1 of :focus)", "Drop|"},
        {":checked", "Drop|"},
        {":-webkit-autofill", "Drop|"},
    };
    std::string out;
    for (const Pair& row : rows) {
        const std::string got = shown(policy::selector(tokens(row.input)));
        if (got != row.expected) {
            out += std::string(" [") + row.input + " → " + got + "]";
        }
    }
    CHECK_EQ(out, std::string(""));
}

WR_TEST(testTheMediaWalker) {
    const char* const in[] = {
        "(max-width: 480px)", "screen and (orientation: portrait)", "only screen", "not all and (min-width: 1px)",
        "(prefers-reduced-motion: reduce)", "(prefers-color-scheme)", "(400px <= width <= 700px)", "(width >= 400px)",
        "(aspect-ratio > 1)", "((min-width: 1px) and (max-width: 9px))", "",
    };
    const char* const out[] = {
        "(hover: hover)", "(pointer: coarse)", "print", "screen, print", "(max-height: 400px)",
        "(min-resolution: 1dppx)", "(color)", "(-webkit-min-device-pixel-ratio: 2)", "tv", "(any-hover)",
    };
    std::string wrong;
    for (const char* prelude : in) {
        if (!policy::mediaQueryInProfile(tokens(prelude))) {
            wrong += std::string(" [in: ") + prelude + "]";
        }
    }
    for (const char* prelude : out) {
        if (policy::mediaQueryInProfile(tokens(prelude))) {
            wrong += std::string(" [out: ") + prelude + "]";
        }
    }
    CHECK_EQ(wrong, std::string(""));
}

WR_TEST(testTheAtRules) {
    for (const char* name : {"media", "supports", "keyframes", "-webkit-keyframes"}) {
        CHECK(policy::atRuleKept(name));
    }
    for (const char* name : {"layer", "import", "font-face", "namespace", "charset", "container", "property", "page",
                             "starting-style"}) {
        CHECK(!policy::atRuleKept(name));
    }
}

WR_TEST(testTheSupportsConditions) {
    const char* const supported[] = {
        "(display: grid)",
        "not (position: sticky)",
        "(display: grid) and (gap: 1px)",
        "(color: oklch(1 0 0)) or (color: red)",
        "selector(a:hover)",
        "((display: flex))",
        "(text-overflow: ellipsis) and (not (text-shadow: 0 0 red))",
        "selector(button:disabled)",
        "(display: flex) and (not (transform: rotateY(10deg)))",
    };
    const char* const unsupported[] = {"(display: flow-root)", "selector(:has(a))", "font-tech(color-COLRv1)",
                                       "selector(a:)"};
    std::string wrong;
    for (const char* condition : supported) {
        if (!policy::supportsCondition(tokens(condition))) {
            wrong += std::string(" [true: ") + condition + "]";
        }
    }
    for (const char* condition : unsupported) {
        if (policy::supportsCondition(tokens(condition))) {
            wrong += std::string(" [false: ") + condition + "]";
        }
    }
    CHECK_EQ(wrong, std::string(""));
}

WR_TEST(testTheURLRules) {
    // The type rules: these are image types of the profile, whatever their bytes (widget-sandbox v0.3.0 then reads the
    // bytes: none of the profile's formats is Broken, not Refused).
    for (const char* src : {"data:image/png;base64,AAAA", "data:IMAGE/PNG;BASE64,x", "data: image/png ,x",
                            "data:image/webp;base64,AA", "\t\ndata:image/png;base64,AA"}) {
        CHECK(policy::imageSource(src) == policy::ImageSource::Broken);
    }
    for (const std::string& src : {std::string("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="), std::string("\t\ndata:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="),
                                   std::string("data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==")}) {
        CHECK(policy::imageSourceKept(src));
    }
    for (const char* src : {"data:image/svg+xml,<svg/>", "data:image/avif;base64,x", "data:image/bmp;base64,x",
                            "data:;base64,x", "#x", "", "\t\nhttp://x", "twplaceholder:", "twcanvas:1:2:3"}) {
        CHECK(!policy::imageSourceKept(src));
    }
    CHECK(policy::fragmentHref("#top") == std::optional<std::string>("#top"));
    CHECK(policy::fragmentHref("  #top ") == std::optional<std::string>("#top"));
    CHECK(policy::fragmentHref("#") == std::optional<std::string>("#"));
    for (const char* href : {"#a b", "#x\"y", "#(x)", "https://x"}) {
        CHECK(!policy::fragmentHref(href));
    }
    CHECK_EQ(policy::normalizedUrl(" ja\nvas\tcript:x \x01"), std::string("javascript:x"));
    CHECK_EQ(policy::reduceFontFamilyText("\"Courier New\", Courier"), std::string("system-ui"));
    CHECK_EQ(policy::reduceFontFamilyText("ui-serif"), std::string("ui-serif,serif"));
}

/// The verdict is a function of its input alone: the same tokens judge alike, and nothing is interned (a hook runs
/// inside litehtml, whose caches key on text, and must not grow litehtml's id table with a widget's names).
WR_TEST(testThePolicyIsPure) {
    const litehtml::css_token_vector value = tokens("ui-monospace, Menlo");
    const policy::Judged first = policy::declaration("font-family", value);
    const policy::Judged second = policy::declaration("font-family", value);
    CHECK(first.verdict == second.verdict);
    CHECK_EQ(litehtml::get_repr(first.value), litehtml::get_repr(second.value));
    const std::string name = "--q-v4-never-seen-7f3a9c";
    policy::declaration(name, tokens("1px"));
    litehtml::string_id id;
    CHECK(!litehtml::_find_id(name, id));
    CHECK(!litehtml::_find_id("q-v4-never-seen-7f3a9c", id));
}

namespace {

/// The fastest of `runs` runs of `f`, in seconds.
double fastest(int runs, const std::function<void()>& f) {
    double best = 1e9;
    for (int i = 0; i < runs; i++) {
        const auto start = std::chrono::steady_clock::now();
        f();
        best = std::min(best, std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count());
    }
    return best;
}

/// Whether `f(n)` grows linearly: eight times the input costs at most 24 times the time (a quadratic costs 64).
bool linear(const char* what, size_t n, const std::function<void(size_t)>& f) {
    const double small = fastest(5, [&] { f(n); });
    const double large = fastest(2, [&] { f(8 * n); });
    const bool ok = large <= 24 * std::max(small, 1e-4);
    if (!ok) {
        std::printf("    %s: %zu → %.4f s, %zu → %.4f s\n", what, n, small, 8 * n, large);
    }
    return ok;
}

} // namespace

/// The final review's C1: the core's rewrites are linear in their input. css_token has no move, so a rewrite that
/// erased or inserted in the middle of a vector copied the rest of it each time, and a family list rescanned every
/// group it kept.
WR_TEST(testTheRewritesAreLinear) {
    CHECK(linear("selector :disabled rewrites", 1000, [](size_t n) {
        std::string text = "a";
        for (size_t i = 0; i < n; i++) {
            text += ":disabled";
        }
        const litehtml::css_token_vector values = tokens(text);
        CHECK(policy::selector(values).verdict == Verdict::Augment);
    }));
    CHECK(linear("filter prune", 1000, [](size_t n) {
        std::string text;
        for (size_t i = 0; i < n; i++) {
            text += "sepia(1) ";
        }
        text += "blur(1px)";
        const litehtml::css_token_vector values = tokens(text);
        CHECK(policy::declaration("filter", values).verdict == Verdict::Rewrite);
    }));
    CHECK(linear("font family groups", 2000, [](size_t n) {
        std::string text;
        for (size_t i = 0; i < n; i++) {
            text += "a(),";
        }
        for (size_t i = 0; i < n; i++) {
            text += "serif,";
        }
        text += "serif";
        CHECK(!policy::reduceFontFamilyText(text).empty());
    }));
}
