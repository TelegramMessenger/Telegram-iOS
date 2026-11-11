// Host test of twidget edit 13 (VENDOR.md): the color scheme in litehtml. prefers-color-scheme, light-dark() and
// color-scheme follow media_features::color_scheme, and the sheet and declaration caches are keyed by it.
#include "test_container.h"

#include <cstdio>

static int failures = 0;

// A container whose scheme the test sets: 0 light, 1 dark.
struct SchemeContainer : litehtml_test::TestContainer {
    int scheme = 0;
    void get_media_features(litehtml::media_features& m) const override {
        litehtml_test::TestContainer::get_media_features(m);
        m.color_scheme = scheme;
    }
};

static litehtml::document::ptr build(SchemeContainer& c, int scheme, const std::string& html) {
    c.scheme = scheme;
    return litehtml_test::layout(c, html);
}

static litehtml::element::ptr by_id(const litehtml::document::ptr& doc, const char* id) {
    return doc->root()->select_one(std::string("#") + id);
}

static bool is(const litehtml::web_color& c, int rgb) {
    return c.alpha == 255 && c.red == ((rgb >> 16) & 255) && c.green == ((rgb >> 8) & 255) && c.blue == (rgb & 255);
}

static bool colorIs(const litehtml::element::ptr& el, int rgb) { return el && is(el->css().get_color(), rgb); }

static void testPrefersColorSchemeMatches() {
    SchemeContainer c;
    const std::string sheet =
        "<style>@media (prefers-color-scheme: dark){p{color:#000001}} @media (prefers-color-scheme: light){p{color:#000002}}"
        " @media (prefers-color-scheme){q{color:#000003}} @media (prefers-color-scheme: no-preference){s{color:#000004}}"
        "</style><p id=p></p><q id=q></q><s id=s></s>";
    auto light = build(c, 0, sheet);
    CHECK(colorIs(by_id(light, "p"), 0x000002));
    CHECK(colorIs(by_id(light, "q"), 0x000003));
    CHECK(!colorIs(by_id(light, "s"), 0x000004));
    auto dark = build(c, 1, sheet);
    CHECK(colorIs(by_id(dark, "p"), 0x000001));
    CHECK(colorIs(by_id(dark, "q"), 0x000003));
    CHECK(!colorIs(by_id(dark, "s"), 0x000004));
}

static void testLightDarkColor() {
    SchemeContainer c;
    const std::string html =
        "<style>#a{color:light-dark(#000001,#000002);background-color:light-dark(#000001,#000002);"
        "border-color:light-dark(#000001,#000002)}"
        "#n{color:light-dark(light-dark(#000001,#000003),#000002)}"
        "#bad{color:light-dark(url(#a),red)}</style>"
        "<div style='color:#000009'><p id=a style='border-style:solid'></p><p id=n></p><p id=bad></p></div>";
    for (int scheme = 0; scheme < 2; scheme++) {
        auto doc = build(c, scheme, html);
        int want = scheme ? 0x000002 : 0x000001;
        auto a = by_id(doc, "a");
        CHECK(colorIs(a, want));
        CHECK(a && is(a->css().get_bg().m_color, want));
        CHECK(a && is(a->css().get_borders().left.color, want));
        CHECK(colorIs(by_id(doc, "n"), scheme ? 0x000002 : 0x000001));
        CHECK(colorIs(by_id(doc, "bad"), 0x000009));
    }
    // A style attribute goes through the declaration cache.
    for (int scheme = 0; scheme < 2; scheme++) {
        auto doc = build(c, scheme, "<p id=a style='color:light-dark(#000001,#000002)'></p>");
        CHECK(colorIs(by_id(doc, "a"), scheme ? 0x000002 : 0x000001));
    }
}

static void testColorSchemeFollowsTheScheme() {
    SchemeContainer c;
    auto check = [&](int scheme, const char* value, bool dark) {
        auto doc = build(c, scheme, std::string("<p id=a style='color-scheme:") + value + "'></p>");
        auto a = by_id(doc, "a");
        bool got = a && a->css().get_dark_scheme();
        if (got != dark) { std::printf("scheme %d color-scheme:%s got %d want %d\n", scheme, value, got, dark); }
        CHECK(got == dark);
    };
    check(0, "light dark", false);
    check(1, "light dark", true);
    check(0, "dark light", false);
    check(1, "dark light", true);
    check(0, "dark", true);
    check(1, "dark", true);
    check(0, "light", false);
    check(1, "light", false);
    check(0, "normal", false);
    check(1, "normal", false);
}

static void testCachesAreKeyedByScheme() {
    SchemeContainer c;
    // The master sheet cache is keyed by the text; a document sheet by its text; a declaration by its text.
    const std::string html = "<style>p{color:light-dark(#000001,#000002)}</style><p id=a></p>"
                             "<p id=b style='background-color:light-dark(#000003,#000004)'></p>";
    for (int round = 0; round < 3; round++) {
        for (int scheme = 0; scheme < 2; scheme++) {
            auto doc = build(c, scheme, html);
            CHECK(colorIs(by_id(doc, "a"), scheme ? 0x000002 : 0x000001));
            auto b = by_id(doc, "b");
            CHECK(b && is(b->css().get_bg().m_color, scheme ? 0x000004 : 0x000003));
        }
    }
    // The master sheet: a document built with a master stylesheet that uses light-dark().
    const char* master = "p{color:light-dark(#000005,#000006)}";
    for (int scheme = 0; scheme < 2; scheme++) {
        c.scheme = scheme;
        auto doc = litehtml::document::createFromString(litehtml::estring("<p id=a></p>"), &c, master);
        doc->render(litehtml::pixel_t(300.0f));
        CHECK(colorIs(by_id(doc, "a"), scheme ? 0x000006 : 0x000005));
    }
}

int main() {
    testPrefersColorSchemeMatches();
    testLightDarkColor();
    testColorSchemeFollowsTheScheme();
    testCachesAreKeyedByScheme();
    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("twidget scheme: OK\n");
    return 0;
}
