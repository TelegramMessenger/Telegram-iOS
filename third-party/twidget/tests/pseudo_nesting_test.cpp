// Host test of twidget edit 19 (VENDOR.md): a pseudo-element never gets pseudo-elements of its own, and a
// pseudo-element's content is capped (32 items, and the elements it makes count against the element cap). Each
// layout runs on a 512 KiB thread, as WidgetRuntime's deep tests do.
#include "test_container.h"

#include <cstdio>
#include <functional>
#include <pthread.h>

static int failures = 0;

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

struct Counting : litehtml_test::TestContainer {
    int limits = 0;
    int elementLimits = 0;
    void sanitizer_limit(const char* what) override {
        limits++;
        if (std::string(what) == "elements") elementLimits++;
    }
};

struct Census {
    int elements = 0;        // not counting text pieces, which have their own cap
    int pseudos = 0;
    int nestedPseudos = 0;   // a pseudo-element with a pseudo-element child
    int images = 0;          // img elements below a pseudo-element
    int maxImagesPerPseudo = 0;
    int text = 0;            // text pieces directly in a pseudo-element
};

static Census census(const litehtml::document::ptr& doc) {
    Census c;
    std::vector<std::pair<litehtml::element::ptr, bool>> pending{{doc->root(), false}};
    while (!pending.empty()) {
        auto [el, inPseudo] = pending.back();
        pending.pop_back();
        if (!el->is_text()) c.elements++;
        const bool isPseudo = el->tag() == litehtml::__tag_before_ || el->tag() == litehtml::__tag_after_;
        if (isPseudo) {
            c.pseudos++;
            int images = 0;
            for (const auto& child : el->children()) {
                if (child->tag() == litehtml::__tag_before_ || child->tag() == litehtml::__tag_after_) c.nestedPseudos++;
                if (child->tag() == litehtml::_img_) images++;
                if (child->is_text()) c.text++;
            }
            c.images += images;
            if (images > c.maxImagesPerPseudo) c.maxImagesPerPseudo = images;
        }
        for (const auto& child : el->children()) pending.push_back({child, inPseudo || isPseudo});
    }
    return c;
}

static std::string divs(int n) {
    std::string r;
    for (int i = 0; i < n; i++) r += "<div>a</div>";
    return r;
}

static void testPseudoElementsDoNotNest() {
    const char* sheets[] = {
        ":not(p)::before{content:'x'}",
        "*::before{content:'y'}",
        "*::after{content:'z'}",
        "::before{content:'w'}",
        "div::before{content:'a'} *::before{content:'b'} :not(p)::after{content:'c'} *::after{content:'d'}",
    };
    for (const char* sheet : sheets) {
        onSmallStack([&] {
            Counting c;
            auto doc = litehtml_test::layout(c, std::string("<style>") + sheet + "</style>" + divs(2));
            CHECK(doc != nullptr);
            if (!doc) return;
            Census k = census(doc);
            CHECK(k.nestedPseudos == 0);
            for (const auto& div : doc->root()->select_all("div")) {
                int pseudos = 0;
                for (const auto& child : div->children())
                    if (child->tag() == litehtml::__tag_before_ || child->tag() == litehtml::__tag_after_) pseudos++;
                CHECK(pseudos <= 2);
            }
        });
    }
    onSmallStack([] {
        Counting c;
        auto doc = litehtml_test::layout(c, "<style>:not(p)::before{content:'x'}</style>" + divs(2));
        Census k = census(doc);
        CHECK(k.nestedPseudos == 0);
        int befores = 0, pieces = 0;
        for (const auto& div : doc->root()->select_all("div")) {
            if (div->children().empty() || div->children().front()->tag() != litehtml::__tag_before_) continue;
            befores++;
            for (const auto& child : div->children().front()->children())
                if (child->is_text()) pieces++;
        }
        CHECK(befores == 2);
        CHECK(pieces == 2);
    });
}

static void testOrdinaryPseudoElementsUnchanged() {
    Counting c;
    auto doc = litehtml_test::layout(c, "<style>p::before{content:'a'} .x::after{content:attr(title)}</style>"
                                        "<p>b</p><span class=x title=hello>c</span>");
    Census k = census(doc);
    CHECK(k.pseudos == 2);
    CHECK(k.nestedPseudos == 0);
    CHECK(k.text == 2);
    auto p = doc->root()->select_one("p");
    CHECK(p && p->children().front()->tag() == litehtml::__tag_before_);
    auto s = doc->root()->select_one(".x");
    CHECK(s && s->children().back()->tag() == litehtml::__tag_after_);
    CHECK(c.limits == 0);
}

static std::string manyUrls(int n) {
    std::string r = "content:";
    for (int i = 0; i < n; i++) r += "url(data:image/gif,a) ";
    return r;
}

static void testPseudoContentIsCapped() {
    // Within the element cap: 32 items per pseudo-element, the first ones kept.
    {
        Counting c;
        auto doc = litehtml_test::layout(c, "<style>div::before{" + manyUrls(1000) + "}</style>" + divs(10));
        Census k = census(doc);
        CHECK(k.pseudos == 10);
        CHECK(k.maxImagesPerPseudo == 32);
        CHECK(k.images == 320);
        CHECK(c.limits == 0);
    }
    // Strings count as items too.
    {
        Counting c;
        std::string content = "content:";
        for (int i = 0; i < 1000; i++) content += "'a' ";
        auto doc = litehtml_test::layout(c, "<style>div::before{" + content + "}</style>" + divs(1));
        auto div = doc->root()->select_one("div");
        CHECK(div && div->children().front()->tag() == litehtml::__tag_before_);
        int pieces = 0;
        for (const auto& child : div->children().front()->children())
            if (child->is_text()) pieces++;
        CHECK(pieces == 32);
    }
    // Past the element cap: the limit is posted once and the elements stop, whatever made them.
    onSmallStack([] {
        Counting c;
        auto doc = litehtml_test::layout(c, "<style>div::before{" + manyUrls(1000) + "}</style>" + divs(1000));
        CHECK(doc != nullptr);
        if (!doc) return;
        Census k = census(doc);
        CHECK(k.elements <= litehtml::document::max_external_elements + 8);
        CHECK(c.elementLimits == 1);
        CHECK(k.images > 0);
    });
}

int main(int argc, char** argv) {
    auto want = [&](const char* name) { return argc < 2 || std::string(argv[1]) == name; };
    if (want("nest")) testPseudoElementsDoNotNest();
    if (want("ordinary")) testOrdinaryPseudoElementsUnchanged();
    if (want("capped")) testPseudoContentIsCapped();
    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("twidget pseudo nesting: OK\n");
    return 0;
}
