// Host test of twidget edit 14 (VENDOR.md): CSS component nesting is bounded at litehtml's componentizer, for every
// caller. Each deep case runs on a 512 KiB thread, as WidgetRuntime's deep tests do.
#include "test_container.h"

#include <cstdio>
#include <functional>
#include <pthread.h>

static int failures = 0;

static std::string repeat(const std::string& s, int n) {
    std::string r;
    r.reserve(s.size() * n);
    for (int i = 0; i < n; i++) r += s;
    return r;
}

static void onSmallStack(std::function<void()> body) {
    struct Box { std::function<void()> fn; } box{std::move(body)};
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, 512 * 1024);
    pthread_t thread;
    int rc = pthread_create(&thread, &attributes, [](void* p) -> void* { static_cast<Box*>(p)->fn(); return nullptr; }, &box);
    CHECK(rc == 0);
    if (rc == 0) pthread_join(thread, nullptr);
    pthread_attr_destroy(&attributes);
}

static litehtml::element::ptr sel(const litehtml::document::ptr& doc, const char* s) { return doc->root()->select_one(s); }

static bool is(const litehtml::web_color& c, int rgb) {
    return c.alpha == 255 && c.red == ((rgb >> 16) & 255) && c.green == ((rgb >> 8) & 255) && c.blue == (rgb & 255);
}
static bool colorIs(const litehtml::element::ptr& el, int rgb) { return el && is(el->css().get_color(), rgb); }

static void testDeepSheetNestingDoesNotCrash() {
    onSmallStack([] {
        litehtml_test::TestContainer c;
        std::string html = "<style>p{color:#000001} q{width:" + repeat("(", 100000) + repeat(")", 100000) +
                           "} r{color:#000002}</style><p>a</p><q>b</q><r>c</r>";
        auto doc = litehtml_test::layout(c, html);
        CHECK(colorIs(sel(doc, "p"), 0x000001));
        CHECK(colorIs(sel(doc, "r"), 0x000002));
        auto q = sel(doc, "q");
        CHECK(q && q->css().get_width().is_predefined());
    });
}

static void testDeepAttributeNestingDoesNotCrash() {
    onSmallStack([] {
        litehtml_test::TestContainer c;
        auto a = litehtml_test::layout(c, "<table width=\"" + repeat("(", 100000) + "\"><tr><td>x</td></tr></table>");
        CHECK(a != nullptr);
        auto b = litehtml_test::layout(c, "<div style=\"width:" + repeat("calc(", 100000) + "\">y</div>");
        CHECK(b != nullptr);
    });
}

static void testDeepLightDarkDoesNotCrash() {
    onSmallStack([] {
        litehtml_test::TestContainer c;
        std::string html = "<style>p{color:" + repeat("light-dark(", 10000) + "red" + repeat(",blue)", 10000) + "}</style><p>a</p>";
        auto doc = litehtml_test::layout(c, html);
        CHECK(doc != nullptr);
    });
}

static void testNestingWithinTheBoundIsUnchanged() {
    litehtml_test::TestContainer c;
    auto doc = litehtml_test::layout(c,
        "<style>p{width:" + repeat("calc(", 10) + "20px" + repeat(")", 10) + "} q{color:#000009} :is(:is(:is(q))){color:#000004}"
        " @media screen{@media screen{s{color:#000003}}}</style><p>a</p><q>b</q><s>c</s>");
    auto p = sel(doc, "p");
    CHECK(p && !p->css().get_width().is_predefined() && p->css().get_width().val() == 20.0f);
    CHECK(colorIs(sel(doc, "q"), 0x000004));
    CHECK(colorIs(sel(doc, "s"), 0x000003));
}


// The bound itself (a property value nested d deep): the boundary is 64 levels. Probed with :is() nested d deep.
static bool widthAppliesAtDepth(int depth) {
    litehtml_test::TestContainer c;
    auto doc = litehtml_test::layout(c, "<style>" + repeat(":is(", depth) + "q" + repeat(")", depth) + "{color:#000004}</style><q>a</q>");
    return colorIs(sel(doc, "q"), 0x000004);
}

static void testTheBoundIs64() {
    CHECK(widthAppliesAtDepth(63));
    CHECK(widthAppliesAtDepth(64));
    CHECK(!widthAppliesAtDepth(65));
    CHECK(!widthAppliesAtDepth(66));
}

// Stray closers of every kind inside a skipped (too deep) block leave the following declarations and rules applied.
static void testStrayClosersInSkippedBlocksLeaveTheRest() {
    for (int depth : {63, 64, 65, 66, 100}) {
        litehtml_test::TestContainer c;
        auto doc = litehtml_test::layout(c, "<style>div{--x:" + repeat("(", depth) + "a ] } ] b" + repeat(")", depth) +
                                                ";color:#000001} p{color:#000002} i{color:#000003}</style><div>a</div><p>b</p><i>c</i>");
        CHECK(colorIs(sel(doc, "div"), 0x000001));
        CHECK(colorIs(sel(doc, "p"), 0x000002));
        CHECK(colorIs(sel(doc, "i"), 0x000003));
    }
    for (int depth : {63, 64, 65, 70}) {
        std::string open, close;
        for (int i = 0; i < depth; i++) open += i % 2 ? "[" : "(";
        for (int i = depth - 1; i >= 0; i--) close += i % 2 ? "]" : ")";
        litehtml_test::TestContainer c;
        auto doc = litehtml_test::layout(c, "<style>div{--y:" + open + " ) ] } " + close + ";color:#000001} p{color:#000002}</style><div>a</div><p>b</p>");
        CHECK(colorIs(sel(doc, "div"), 0x000001));
        CHECK(colorIs(sel(doc, "p"), 0x000002));
    }
}

// With an argument, runs only the named test (to see which one fails); with none, all of them.
int main(int argc, char** argv) {
    auto want = [&](const char* name) { return argc < 2 || std::string(argv[1]) == name; };
    if (want("within")) testNestingWithinTheBoundIsUnchanged();
    if (want("bound")) testTheBoundIs64();
    if (want("stray")) testStrayClosersInSkippedBlocksLeaveTheRest();
    if (want("sheet")) testDeepSheetNestingDoesNotCrash();
    if (want("attribute")) testDeepAttributeNestingDoesNotCrash();
    if (want("lightdark")) testDeepLightDarkDoesNotCrash();
    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("twidget css nesting: OK\n");
    return 0;
}
