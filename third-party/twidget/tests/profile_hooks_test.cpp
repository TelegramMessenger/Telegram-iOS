// Host test of twidget edit 29 (VENDOR.md): the profile hooks a container answers (WidgetRuntime's profile policy, V4).
// A mutable declaration hook, a selector-group hook, an @media prelude hook, an @supports answer, prefers-reduced-motion,
// a hook after var() substitution, and a sanitizer key that keeps two containers apart in litehtml's caches.
#include "test_container.h"

#include <litehtml/css_parser.h>

#include <cstdio>
#include <functional>
#include <string>
#include <vector>

static int failures = 0;

using litehtml::css_token;
using litehtml::css_token_vector;

struct HookContainer : litehtml_test::TestContainer {
    std::function<bool(std::string&, css_token_vector&, bool&)> declaration;
    std::function<void(std::vector<css_token_vector>&)> selectors;
    std::function<bool(const css_token_vector&)> media;
    std::function<int(const css_token_vector&)> supports;
    std::function<bool(const std::string&, css_token_vector&)> substituted;
    std::function<bool(const std::string&, const css_token_vector&)> sanitize;
    int reducedMotion = 0;
    uint32_t key = 0;

    bool profile_declaration(std::string& name, css_token_vector& value, bool& important) override {
        return declaration ? declaration(name, value, important) : litehtml_test::TestContainer::profile_declaration(name, value, important);
    }
    bool sanitize_declaration(const std::string& name, const css_token_vector& value) override {
        return sanitize ? sanitize(name, value) : true;
    }
    void sanitize_selector_list(std::vector<css_token_vector>& groups) override {
        if (selectors) {
            selectors(groups);
        }
    }
    bool sanitize_media_query(const css_token_vector& prelude) override { return media ? media(prelude) : true; }
    int evaluate_supports(const css_token_vector& condition) override { return supports ? supports(condition) : -1; }
    bool profile_substituted(const std::string& name, css_token_vector& value) override {
        return substituted ? substituted(name, value) : true;
    }
    uint32_t sanitizer_key() const override { return key; }
    void get_media_features(litehtml::media_features& m) const override {
        litehtml_test::TestContainer::get_media_features(m);
        m.reduced_motion = reducedMotion;
    }
};

static litehtml::element::ptr by_id(const litehtml::document::ptr& doc, const char* id) {
    return doc->root()->select_one(std::string("#") + id);
}

static bool colorIs(const litehtml::element::ptr& el, int rgb) {
    if (!el) {
        return false;
    }
    const litehtml::web_color c = el->css().get_color();
    return c.alpha == 255 && c.red == ((rgb >> 16) & 255) && c.green == ((rgb >> 8) & 255) && c.blue == (rgb & 255);
}

/// Whether a group holds the identifier or function `name` anywhere.
static bool holds(const css_token_vector& tokens, const std::string& name) {
    for (const css_token& t : tokens) {
        if ((t.type == litehtml::IDENT || t.type == litehtml::CV_FUNCTION) && t.name() == name) {
            return true;
        }
        if (t.is_component_value() && holds(t.value, name)) {
            return true;
        }
    }
    return false;
}

static void testTheDeclarationHookRewrites() {
    HookContainer c;
    bool sawImportant = false;
    c.declaration = [&](std::string& name, css_token_vector& value, bool& important) {
        if (name == "color" && important) {
            sawImportant = true;
        }
        if (name == "position" && value.size() == 1 && value[0].ident() == "sticky") {
            value = litehtml::normalize(std::string("relative"), litehtml::f_componentize);
        }
        return true;
    };
    auto doc = litehtml_test::layout(c, "<style>#s{position:sticky} p{color:red !important}</style><div id=s></div><p>x</p>");
    auto s = by_id(doc, "s");
    CHECK(s && s->css().get_position() == litehtml::element_position_relative);
    CHECK(sawImportant);
}

static void testTheDefaultCallsSanitizeDeclaration() {
    HookContainer c;
    c.sanitize = [](const std::string& name, const css_token_vector&) { return name != "color"; };
    auto doc = litehtml_test::layout(c, "<style>#p{color:#000001}</style><p id=p>x</p>");
    CHECK(!colorIs(by_id(doc, "p"), 0x000001));
}

static void testTheSelectorHookDropsOneGroup() {
    HookContainer c;
    c.selectors = [](std::vector<css_token_vector>& groups) {
        for (size_t i = 0; i < groups.size();) {
            if (holds(groups[i], "has")) {
                groups.erase(groups.begin() + std::ptrdiff_t(i));
            } else {
                i++;
            }
        }
    };
    auto doc = litehtml_test::layout(c, "<style>.a:has(.b), .c{color:#000003}</style><p class=c id=c>x</p>");
    CHECK(colorIs(by_id(doc, "c"), 0x000003));
    doc = litehtml_test::layout(c, "<style>.c, ..d{color:#000004}</style><p class=c id=c>x</p>");
    CHECK(!colorIs(by_id(doc, "c"), 0x000004));
    doc = litehtml_test::layout(c, "<style>.x, .y{color:#000005}</style><p class=x id=x>x</p><p class=y id=y>y</p>");
    CHECK(colorIs(by_id(doc, "x"), 0x000005));
    CHECK(colorIs(by_id(doc, "y"), 0x000005));
}

// The hook's second site, a <link media> sheet, cannot be reached here: the fork's <style> (el_style, an `element`)
// keeps no attributes, so a <style media> sheet always applies, and the test container imports nothing.
static void testTheMediaHook() {
    HookContainer c;
    c.media = [](const css_token_vector& prelude) { return !holds(prelude, "hover"); };
    auto doc = litehtml_test::layout(c,
        "<style>@media (hover:hover){p{color:#000006}} @media (min-width:1px){q{color:#000008}}</style>"
        "<p id=p>p</p><q id=q>q</q>");
    CHECK(!colorIs(by_id(doc, "p"), 0x000006));
    CHECK(colorIs(by_id(doc, "q"), 0x000008));
}

static void testEvaluateSupports() {
    HookContainer c;
    const std::string html = "<style>@supports (display:flex){#a{color:#00000a}} @supports (transform:rotateY(1deg)){#b{color:#00000b}}"
                             "</style><p id=a>a</p><p id=b>b</p>";
    // A hook is a pure function of the text: each answer below is another container, under a sanitizer key of its
    // own, or litehtml's author-sheet cache would serve the first answer to the next.
    c.key = 0x5501;
    auto doc = litehtml_test::layout(c, html);
    CHECK(colorIs(by_id(doc, "a"), 0x00000a));
    c.key = 0x5502;
    c.supports = [](const css_token_vector&) { return 1; };
    doc = litehtml_test::layout(c, html);
    CHECK(colorIs(by_id(doc, "b"), 0x00000b));
    c.key = 0x5503;
    c.supports = [](const css_token_vector&) { return 0; };
    doc = litehtml_test::layout(c, html);
    CHECK(!colorIs(by_id(doc, "a"), 0x00000a));
}

static void testPrefersReducedMotion() {
    HookContainer c;
    const std::string html =
        "<style>@media (prefers-reduced-motion: no-preference){#n{color:#00000c}}"
        " @media (prefers-reduced-motion: reduce){#r{color:#00000d}} @media (prefers-reduced-motion){#b{color:#00000e}}</style>"
        "<p id=n>n</p><p id=r>r</p><p id=b>b</p>";
    c.reducedMotion = 0;
    auto doc = litehtml_test::layout(c, html);
    CHECK(colorIs(by_id(doc, "n"), 0x00000c));
    CHECK(!colorIs(by_id(doc, "r"), 0x00000d));
    CHECK(!colorIs(by_id(doc, "b"), 0x00000e));
    c.reducedMotion = 1;
    doc = litehtml_test::layout(c, html);
    CHECK(!colorIs(by_id(doc, "n"), 0x00000c));
    CHECK(colorIs(by_id(doc, "r"), 0x00000d));
    CHECK(colorIs(by_id(doc, "b"), 0x00000e));
}

static void testTheSubstitutedHook() {
    HookContainer c;
    c.substituted = [](const std::string& name, css_token_vector& value) {
        if (name == "position" && !value.empty() && value[0].ident() == "sticky") {
            value = litehtml::normalize(std::string("relative"), litehtml::f_componentize);
        }
        return true;
    };
    auto doc = litehtml_test::layout(c, "<div id=v style='--p:sticky;position:var(--p)'></div>");
    auto v = by_id(doc, "v");
    CHECK(v && v->css().get_position() == litehtml::element_position_relative);
    c.substituted = [](const std::string& name, css_token_vector&) { return name != "position"; };
    doc = litehtml_test::layout(c, "<div id=w style='--p:absolute;position:var(--p)'></div>");
    auto w = by_id(doc, "w");
    CHECK(w && w->css().get_position() == litehtml::element_position_static);
}

static void testTheSanitizerKeySplitsTheCaches() {
    HookContainer open;
    HookContainer strict;
    open.key = 0;
    strict.key = 7;
    strict.sanitize = [](const std::string& name, const css_token_vector&) { return name != "color"; };
    const std::string html = "<p id=p style=\"color:#000009\">x</p>";
    CHECK(colorIs(by_id(litehtml_test::layout(open, html), "p"), 0x000009));
    CHECK(!colorIs(by_id(litehtml_test::layout(strict, html), "p"), 0x000009));
    CHECK(colorIs(by_id(litehtml_test::layout(open, html), "p"), 0x000009));
    const std::string sheet = "<style>#q{color:#00000f}</style><p id=q>q</p>";
    CHECK(colorIs(by_id(litehtml_test::layout(open, sheet), "q"), 0x00000f));
    CHECK(!colorIs(by_id(litehtml_test::layout(strict, sheet), "q"), 0x00000f));
}

struct RecordingContainer : litehtml_test::TestContainer {
    bool trusted = false;
    int untrustedAtRules = 0;
    int trustedAtRules = 0;
    void trusted_styles(bool value) override { trusted = value; }
    bool sanitize_at_rule(const std::string&) override {
        (trusted ? trustedAtRules : untrustedAtRules)++;
        return true;
    }
};

static void testTrustedStylesBracketTheMaster() {
    RecordingContainer c;
    // A master sheet new to the process, holding an at-rule: parsed (not cached) inside the trusted bracket.
    auto doc = litehtml::document::createFromString(litehtml::estring("<p>x</p>"), &c,
                                                    "@keyframes v4-master-probe{} p{color:red}");
    doc->render(litehtml::pixel_t(300.0f));
    CHECK(c.trustedAtRules >= 1);
    CHECK(c.untrustedAtRules == 0);
}

int main() {
    testTheDeclarationHookRewrites();
    testTheDefaultCallsSanitizeDeclaration();
    testTheSelectorHookDropsOneGroup();
    testTheMediaHook();
    testEvaluateSupports();
    testPrefersReducedMotion();
    testTheSubstitutedHook();
    testTheSanitizerKeySplitsTheCaches();
    testTrustedStylesBracketTheMaster();
    if (failures) {
        std::printf("%d failure(s)\n", failures);
        return 1;
    }
    std::printf("profile hooks: all passed\n");
    return 0;
}
