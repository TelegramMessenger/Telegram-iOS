// The render build (M1c plan, Task 5): the whole litehtml document built from the runtime's DOM, laid out, recorded
// and published atomically. What is not rendered (Ruling 4), the render limits (Ruling 7), the charges (Ruling 9), a
// stop in the middle of a build (Review Focus 2) and hostile sizes (Review Focus 4).
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <functional>
#include <memory>
#include <string>
#include <utility>
#include <variant>
#include <vector>

#include <litehtml.h>
#include <litehtml/telegram_master_css.h>
#include <atomic>
#include <cstdlib>
#include <new>

#include <malloc/malloc.h>
#include <pthread.h>

#include "Sources/Render/Builder.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderDump.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Render/WidgetContainer.h"
#include "Sources/Support/Errors.h"
#include "Tests/RenderHarness.h"

using wr_test::findText;
using wr_test::RenderEnv;

namespace {

// A 3×2 RGBA PNG (signature, IHDR, IDAT, IEND).
const std::string kPng3x2 =
    "data:image/png;base64,"
    "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAEUlEQVR4nGP4z8DwH4YZkDkAm34L9XKwuTwAAAAASUVORK5CYII=";

const char* const kEmpty = "<!doctype html><html><head></head><body></body></html>";

// A layout dump's lines as (depth, tag).
std::vector<std::pair<size_t, std::string>> dumpTags(const std::string& dump) {
    std::vector<std::pair<size_t, std::string>> tags;
    size_t start = 0;
    while (start < dump.size()) {
        size_t end = dump.find('\n', start);
        if (end == std::string::npos) {
            end = dump.size();
        }
        size_t indent = 0;
        while (start + indent < end && dump[start + indent] == ' ') {
            indent++;
        }
        const size_t nameEnd = dump.find(' ', start + indent);
        tags.emplace_back(indent / 2, dump.substr(start + indent, std::min(nameEnd, end) - start - indent));
        start = end + 1;
    }
    return tags;
}

// The first line of `dump` whose tag, after its indent, is `tag`; "" when there is none.
std::string lineFor(const std::string& dump, const std::string& tag) {
    size_t start = 0;
    while (start < dump.size()) {
        size_t end = dump.find('\n', start);
        if (end == std::string::npos) {
            end = dump.size();
        }
        size_t first = dump.find_first_not_of(' ', start);
        if (first < end && dump.compare(first, tag.size() + 1, tag + " ") == 0) {
            return dump.substr(start, end - start);
        }
        start = end + 1;
    }
    return {};
}

// The last number of a layout dump line: the height.
double heightOf(const std::string& line) {
    const size_t space = line.rfind(' ');
    return space == std::string::npos ? -1 : std::stod(line.substr(space + 1));
}

size_t count(const std::string& haystack, const std::string& needle) {
    size_t found = 0;
    for (size_t at = haystack.find(needle); at != std::string::npos; at = haystack.find(needle, at + needle.size())) {
        found++;
    }
    return found;
}

size_t diagnosticCount(RenderEnv& env, const std::string& kind, const std::string& detail) {
    size_t found = 0;
    for (const auto& [k, d] : env.env().host().diagnostics) {
        if (k == kind && d == detail) {
            found++;
        }
    }
    return found;
}

size_t renderLimitCount(RenderEnv& env) {
    size_t found = 0;
    for (const auto& entry : env.env().host().diagnostics) {
        if (entry.first == "render-limit") {
            found++;
        }
    }
    return found;
}

// The first litehtml element in tree order whose tag is `tag`.
litehtml::element::ptr findElement(litehtml::document& document, const std::string& tag) {
    std::vector<litehtml::element::ptr> stack{document.root()};
    while (!stack.empty()) {
        litehtml::element::ptr element = stack.back();
        stack.pop_back();
        if (!element) {
            continue;
        }
        const char* name = element->get_tagName();
        if (!element->is_text() && name && tag == name) {
            return element;
        }
        const auto& children = element->children();
        for (auto child = children.rbegin(); child != children.rend(); ++child) {
            stack.push_back(*child);
        }
    }
    return nullptr;
}

bool hasColor(const litehtml::element::ptr& element, uint8_t red, uint8_t green, uint8_t blue) {
    if (!element) {
        return false;
    }
    const litehtml::web_color color = element->css().get_color();
    return color.red == red && color.green == green && color.blue == blue;
}

// Runs `body` on a thread with a 512 KiB stack, as ParserTests' deep inputs do (pool threads have 2 MB). The runtime
// is used from that thread alone while it runs; QuickJS's stack top follows it there and back. A build 255 levels
// deep (litehtml's layout recurses per level) needs between 192 and 256 KiB; AddressSanitizer's frames take several
// times that, so an instrumented run gets the pool's 2 MB.
#if defined(__has_feature)
#if __has_feature(address_sanitizer)
#define WR_RENDER_TEST_STACK (2 * 1024 * 1024)
#endif
#endif
#ifndef WR_RENDER_TEST_STACK
#define WR_RENDER_TEST_STACK (512 * 1024)
#endif
void onSmallStack(JSRuntime* rt, const std::function<void()>& body) {
    struct Call {
        JSRuntime* rt;
        const std::function<void()>* body;
    } call{rt, &body};
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, WR_RENDER_TEST_STACK);
    pthread_t thread;
    auto run = [](void* argument) -> void* {
        auto* c = static_cast<Call*>(argument);
        JS_UpdateStackTop(c->rt);
        (*c->body)();
        return nullptr;
    };
    CHECK(pthread_create(&thread, &attributes, run, &call) == 0);
    pthread_join(thread, nullptr);
    pthread_attr_destroy(&attributes);
    JS_UpdateStackTop(rt);
}

size_t heapInUse() {
    malloc_statistics_t stats{};
    malloc_zone_statistics(nullptr, &stats);
    return stats.size_in_use;
}

// Rebuilds, and answers whether it threw Aborted.
bool rebuildAborts(RenderEnv& env) {
    try {
        env.rebuild();
    } catch (const wr::Aborted&) {
        return true;
    }
    return false;
}

// The largest single operator-new allocation while tracking is on (testLongNamesAreChargedBeforeConversion). A
// conversion that is freed when the stop unwinds leaves no heap growth behind, but its allocation is seen here.
std::atomic<bool> gTrackAllocations{false};
std::atomic<size_t> gLargestAllocation{0};

} // namespace

// The global operator new and delete, replaced for the whole test binary to feed gLargestAllocation. They forward to
// malloc and free, as libc++'s own do; libc++'s other forms (array, nothrow, sized) call these.
void* operator new(size_t size) {
    if (gTrackAllocations.load(std::memory_order_relaxed)) {
        size_t seen = gLargestAllocation.load(std::memory_order_relaxed);
        while (size > seen && !gLargestAllocation.compare_exchange_weak(seen, size, std::memory_order_relaxed)) {
        }
    }
    if (void* p = std::malloc(size ? size : 1)) {
        return p;
    }
    throw std::bad_alloc();
}

void operator delete(void* p) noexcept {
    std::free(p);
}

WR_TEST(testBuildMirrorsTheDom) {
    RenderEnv env("<!doctype html><p class=a>Hi <b>x</b></p>");
    // A tree builds nothing until its first build. The installed one's was the boot's flush (Task 6).
    {
        wr::RenderTree fresh(env.ctx(), env.host(), env.options());
        CHECK(fresh.layerTree() == nullptr);
        CHECK(fresh.document() == nullptr);
        CHECK_EQ(fresh.layoutDump(), std::string());
        CHECK_EQ(fresh.renderInput(), std::string());
        CHECK_EQ(fresh.buildCount(), uint64_t(0));
    }
    CHECK_EQ(env.render().buildCount(), uint64_t(1));
    const auto tags = dumpTags(env.render().layoutDump());
    const std::vector<std::pair<size_t, std::string>> expected = {
        {0, "html"}, {1, "head"}, {1, "body"}, {2, "p"}, {3, "b"}};
    CHECK(tags == expected);
    CHECK_EQ(env.render().renderInput(),
             std::string("<!doctype html><html><head></head><body><p class=\"a\">Hi <b>x</b></p></body></html>"));
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    CHECK(tree != nullptr);
    CHECK(tree && findText(*tree, "Hi") != nullptr);
    // The first publish has no previous tree: everything changed.
    CHECK(!env.render().changedRects().has_value());
    // A second build of the same DOM paints the same: no changed rect.
    env.rebuild();
    CHECK_EQ(env.render().buildCount(), uint64_t(2));
    CHECK(env.render().changedRects().has_value() && env.render().changedRects()->empty());
    CHECK(env.render().layerTree() != tree);
    if (!tags.empty() && tags != expected) {
        std::printf("  layoutDump:\n%s", env.render().layoutDump().c_str());
    }
}

WR_TEST(testBuildPathParity) {
    const char* const fixtures[] = {
        "<!doctype html><p>Some text runs: <b>bold</b>, <i>italic</i>, <span style='font-size:20px'>larger</span> and "
        "<small>small</small>, long enough to wrap twice at this width, with <sub>sub</sub> and <sup>super</sup>.</p>",
        "<!doctype html><table border=1 cellpadding=2><tr><th>head</th><th>wider head</th></tr><tr><td>a</td><td>bb</td>"
        "</tr><tr><td colspan=2>a cell across both columns with some text</td></tr></table>",
        "<!doctype html><pre>line one\n  line two, indented\n\tthree after a tab\n\n</pre><p>after &amp; &lt;x&gt; "
        "&nbsp;nbsp</p>",
        "<!doctype html><ul><li>one<ol><li>a</li><li>b<ul><li>deep</li></ul></li></ol></li><li>two</li></ul>\n"
        "<p title='a \"quoted\" &amp; value'>x</p>",
        "<!doctype html><head><style>.box { padding: 4px; margin: 2px; border: 1px solid red } .wide { width: 120px } "
        ".row { display: flex; gap: 6px } .row > * { flex: 1 } p > b { margin-left: 3px }</style></head><body>\n"
        "<div class='box wide'>x</div><div class=box>y z</div>\n"
        "<div class=row><span>left</span><span class=box>right</span></div></body>",
        "<!doctype html><form><input type=text value=hi><input type=checkbox checked><input type=radio>"
        "<input type=range><select><option>one</option><option selected>two</option></select><button>Go</button>"
        "<textarea>t</textarea><input placeholder='a placeholder'></form>",
        "<!doctype html><svg viewBox='0 0 20 20' width=20 height=20><defs><linearGradient id=g><stop offset=0 "
        "stop-color=red /></linearGradient></defs><rect width=10 height=10 fill='url(#g)'/></svg><p>after</p>",
    };
    for (const char* fixture : fixtures) {
        RenderEnv env(fixture);
        env.rebuild();
        const std::string ours = env.render().layoutDump();
        // A second container over the same host, laid out from renderInput through litehtml's own parser. The
        // document goes before its container.
        wr::WidgetContainer container(env.host(), env.options());
        std::string theirs;
        {
            litehtml::document::ptr parsed = litehtml::document::createFromString(
                litehtml::estring(env.render().renderInput()), &container, wr::masterWithHostCSS(env.options().hostCSS));
            parsed->render(litehtml::pixel_t(float(env.options().width)));
            theirs = wr::dumpLayout(*parsed);
        }
        CHECK_EQ(ours, theirs);
        CHECK(dumpTags(ours).size() > 3);
        if (ours != theirs) {
            std::printf("  renderInput: %s\n  built:\n%s  parsed:\n%s", env.render().renderInput().c_str(), ours.c_str(),
                        theirs.c_str());
        }
    }
}

WR_TEST(testUnrenderedContent) {
    // Ruling 4's elements, made by script: from markup, the void ones (link, meta, base, area, source, track, param)
    // could not hold a child, script and title take raw text, and the parser drops frameset and frame in a body.
    const char* const names[] = {"script", "noscript", "template", "iframe", "frame", "frameset", "noframes", "object",
                                 "embed", "noembed", "applet", "param", "portal", "fencedframe", "video", "audio",
                                 "source", "track", "math", "link", "meta", "base", "title", "area"};
    RenderEnv env(kEmpty);
    std::string script = "for (const name of [";
    for (const char* name : names) {
        script += std::string("'") + name + "',";
    }
    script += "]) { const e = document.createElement(name); const b = document.createElement('b'); b.textContent = 'X';"
              " e.appendChild(b); document.body.appendChild(e); }"
              // In any namespace: MathML's math, an SVG title, and an HTML element named in upper case.
              "const m = document.createElementNS('http://www.w3.org/1998/Math/MathML', 'math');"
              "m.appendChild(document.createElement('b')).textContent = 'X'; document.body.appendChild(m);"
              "const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');"
              "const t = svg.appendChild(document.createElementNS('http://www.w3.org/2000/svg', 'title'));"
              "t.textContent = 'X'; document.body.appendChild(svg);"
              "const u = document.createElementNS('http://www.w3.org/1999/xhtml', 'SCRIPT');"
              "u.appendChild(document.createElement('b')).textContent = 'X'; document.body.appendChild(u);"
              "document.body.appendChild(document.createComment('C'));"
              "const tpl = document.createElement('template'); tpl.innerHTML = '<i>T</i>'; document.body.appendChild(tpl);"
              "const p = document.createElement('p'); p.textContent = 'after'; document.body.appendChild(p); 'ok'";
    CHECK_EQ(env.env().eval(script), std::string("ok"));
    env.rebuild();
    const std::string input = env.render().renderInput();
    CHECK(input.find('X') == std::string::npos);
    CHECK(input.find('T') == std::string::npos);
    CHECK(input.find("<!--") == std::string::npos);
    CHECK(input.find("<b>") == std::string::npos);
    for (const char* name : names) {
        CHECK(input.find(std::string("<") + name) == std::string::npos);
    }
    CHECK(input.find("<p>after</p>") != std::string::npos);
    const std::string dump = env.render().layoutDump();
    CHECK(!lineFor(dump, "p").empty());
    CHECK(lineFor(dump, "b").empty());
    CHECK(lineFor(dump, "i").empty());
    CHECK(!lineFor(dump, "svg").empty());
    CHECK_EQ(renderLimitCount(env), size_t(0));
    if (input.find("<p>after</p>") == std::string::npos) {
        std::printf("  renderInput: %s\n", input.c_str());
    }
}

WR_TEST(testEverythingElseRendersAsItIs) {
    RenderEnv env("<!doctype html><style>my-card{display:block;height:10px}</style>"
                  "<my-card class=x onclick=\"f()\" data-tg-link=\"\" data-lh-id=7>c</my-card>");
    env.rebuild();
    const std::string dump = env.render().layoutDump();
    const std::string line = lineFor(dump, "my-card");
    CHECK(!line.empty());
    CHECK_EQ(heightOf(line), 10.0);
    const std::string input = env.render().renderInput();
    CHECK(input.find("<my-card class=\"x\" onclick=\"f()\" data-tg-link=\"\" data-lh-id=\"7\">c</my-card>") !=
          std::string::npos);
    litehtml::element::ptr card = findElement(*env.render().document(), "my-card");
    CHECK(card && card->get_attr("data-lh-id") && std::string(card->get_attr("data-lh-id")) == "7");
    CHECK(card && card->get_attr("onclick") && std::string(card->get_attr("onclick")) == "f()");
    if (line.empty() || heightOf(line) != 10.0) {
        std::printf("  layoutDump:\n%s  renderInput: %s\n", dump.c_str(), input.c_str());
    }
}

WR_TEST(testStyleTextIsItsTextChildren) {
    // From markup, `<!--q{…}-->` inside a <style> is text (a raw-text element), and CSS ignores the CDO and CDC
    // tokens, so the rule would apply. A Comment child is made by script: its data is not the sheet's (Ruling 10).
    RenderEnv env("<!doctype html><style id=s>p{color:#000001}</style><p>a</p><q>b</q><i>c</i>");
    CHECK_EQ(env.env().eval("const s = document.getElementById('s');"
                            "s.appendChild(document.createComment('q{color:#000002}'));"
                            "s.appendChild(document.createTextNode(' i{color:#000003}')); s.childNodes.length"),
             std::string("3"));
    env.rebuild();
    litehtml::document& document = *env.render().document();
    CHECK(hasColor(findElement(document, "p"), 0, 0, 1));
    CHECK(!hasColor(findElement(document, "q"), 0, 0, 2));
    CHECK(hasColor(findElement(document, "i"), 0, 0, 3));
    CHECK(env.render().renderInput().find("<style id=\"s\">p{color:#000001} i{color:#000003}</style>") !=
          std::string::npos);
}

WR_TEST(testCssCaps) {
    auto sheet = [](const std::string& rule, size_t bytes) {
        std::string text = rule + "/*";
        text.append(bytes - text.size() - 2, 'x');
        return text + "*/";
    };
    const std::string first = sheet("p{color:#000001}", 40000);
    const std::string second = sheet("q{color:#000002}", 40000);
    // The boot's flush is the build.
    RenderEnv env("<!doctype html><style>" + first + "</style><style>" + second + "</style><p>a</p><q>b</q>");
    litehtml::document& document = *env.render().document();
    CHECK(hasColor(findElement(document, "p"), 0, 0, 1));
    CHECK(!hasColor(findElement(document, "q"), 0, 0, 2));
    CHECK_EQ(diagnosticCount(env, "render-limit", "css"), size_t(1));
    const std::string input = env.render().renderInput();
    CHECK(input.find("<style>" + first + "</style><style></style>") != std::string::npos);

    // 16,384 bytes of `style` attribute are rendered; 16,385 are not.
    auto value = [](const std::string& declaration, size_t bytes) {
        std::string text = declaration + "/*";
        text.append(bytes - text.size() - 2, 'x');
        return text + "*/";
    };
    const std::string kept = value("color:#000003;", 16384);
    const std::string dropped = value("color:#000004;", 16385);
    RenderEnv attributes("<!doctype html><b style='" + kept + "'>k</b><i style='" + dropped + "'>d</i>");
    const std::string attributeInput = attributes.render().renderInput();
    CHECK(attributeInput.find("<b style=\"" + kept + "\">k</b>") != std::string::npos);
    CHECK(attributeInput.find("<i>d</i>") != std::string::npos);
    CHECK_EQ(count(attributeInput, "style="), size_t(1));
    CHECK(hasColor(findElement(*attributes.render().document(), "b"), 0, 0, 3));
    CHECK(!hasColor(findElement(*attributes.render().document(), "i"), 0, 0, 4));
    CHECK_EQ(diagnosticCount(attributes, "render-limit", "style-attribute"), size_t(1));
    CHECK_EQ(diagnosticCount(attributes, "render-limit", "css"), size_t(0));
}

WR_TEST(testRenderByteBudget) {
    const std::string a(600 * 1024, 'a');
    const std::string b(600 * 1024, 'b');
    // The boot's flush is the first build.
    RenderEnv env("<!doctype html><p>" + a + "</p><p>" + b + "</p><p>x</p>");
    const std::string input = env.render().renderInput();
    // The second <p> comes before its text in tree order, so it renders, empty; its text would pass the 1 MiB, so
    // neither it nor anything after it renders.
    CHECK(input.find("<p>" + a + "</p><p></p></body></html>") != std::string::npos);
    CHECK(input.find("bbbb") == std::string::npos);
    CHECK(input.find("<p>x</p>") == std::string::npos);
    CHECK_EQ(diagnosticCount(env, "render-limit", "bytes"), size_t(1));
    CHECK_EQ(count(env.render().layoutDump(), "    p "), size_t(2));
    // Each build posts its limits again, once.
    env.rebuild();
    CHECK_EQ(diagnosticCount(env, "render-limit", "bytes"), size_t(2));
}

namespace {

struct HostileCase {
    const char* name;
    const char* script;
    std::function<void(RenderEnv&)> check;
};

} // namespace

WR_TEST(testHostileSizesAreBoundedAndCharged) {
    // RenderTree.h's memory bound: each hostile single build's heap growth stays under 160 MB.
    const size_t kCeiling = size_t(160) * 1000 * 1000;
    const HostileCase cases[] = {
        {"elements",
         "for (let i = 0; i < 25000; i++) document.body.appendChild(document.createElement('div'));",
         [&](RenderEnv& env) {
             // Ruling E9's 10,000, which html, head and body count toward.
             CHECK_EQ(dumpTags(env.render().layoutDump()).size(), size_t(10000));
             CHECK_EQ(diagnosticCount(env, "render-limit", "elements"), size_t(1));
         }},
        {"styled-elements",
         "{ const s = document.createElement('style'); s.textContent = 'div{border:1px solid red;background:#eee;"
         "box-shadow:0 0 2px #000;border-radius:3px;overflow:hidden;height:2px}'; document.head.appendChild(s);"
         " for (let i = 0; i < 20000; i++) document.body.appendChild(document.createElement('div')); }",
         [&](RenderEnv& env) {
             // The bound's headline shape (RenderTree.h): html, head, the style and body count toward the 10,000.
             CHECK_EQ(dumpTags(env.render().layoutDump()).size(), size_t(10000));
             CHECK_EQ(diagnosticCount(env, "render-limit", "elements"), size_t(1));
             // Each div's shadow, background and borders. Its overflow clip opens and closes on every pass with nothing
             // inside, a pair the published mirror does not hold (Task 10b, Ruling E37).
             CHECK(env.render().layerTree()->itemCount() >= 9996 * 3);
         }},
        {"depth",
         "{ let p = document.body; for (let i = 0; i < 300; i++) p = p.appendChild(document.createElement('div')); }",
         [&](RenderEnv& env) {
             size_t deepest = 0;
             for (const auto& [depth, tag] : dumpTags(env.render().layoutDump())) {
                 deepest = std::max(deepest, depth);
             }
             // external_element_allowed refuses depth 256 (the root is 0).
             CHECK_EQ(deepest, size_t(255));
             CHECK_EQ(diagnosticCount(env, "render-limit", "depth"), size_t(1));
         }},
        {"text-pieces",
         "for (let i = 0; i < 10001; i++) document.body.appendChild(document.createTextNode('w'));",
         [&](RenderEnv& env) {
             CHECK_EQ(env.render().document()->text_elements(), 10000);
             CHECK_EQ(diagnosticCount(env, "render-limit", "text-pieces"), size_t(1));
         }},
        {"css",
         "{ const s = document.createElement('style'); s.textContent = 'p{color:#000001}' + ' '.repeat(2 * 1024 * 1024);"
         " document.head.appendChild(s); document.body.appendChild(document.createElement('p')).textContent = 'p'; }",
         [&](RenderEnv& env) {
             CHECK(!hasColor(findElement(*env.render().document(), "p"), 0, 0, 1));
             CHECK(findElement(*env.render().document(), "p") != nullptr);
             CHECK_EQ(diagnosticCount(env, "render-limit", "css"), size_t(1));
         }},
        {"style-attribute",
         "document.body.appendChild(document.createElement('i')).setAttribute('style', 'color:#000004;' + "
         "' '.repeat(16385));",
         [&](RenderEnv& env) {
             CHECK(!hasColor(findElement(*env.render().document(), "i"), 0, 0, 4));
             CHECK_EQ(diagnosticCount(env, "render-limit", "style-attribute"), size_t(1));
         }},
        {"bytes",
         "document.body.textContent = 'a'.repeat(2 * 1024 * 1024);",
         [&](RenderEnv& env) {
             CHECK(env.render().renderInput().find("aaaa") == std::string::npos);
             CHECK_EQ(diagnosticCount(env, "render-limit", "bytes"), size_t(1));
         }},
        {"inputs",
         "for (let i = 0; i < 20000; i++) document.body.appendChild(document.createElement('input'));",
         [&](RenderEnv& env) {
             // Ruling E6: 256 form controls render (20,000 measured 436 MB before the limit).
             CHECK_EQ(count(env.render().layoutDump(), "\n    input "), size_t(256));
             CHECK_EQ(diagnosticCount(env, "render-limit", "form-controls"), size_t(1));
             CHECK_EQ(diagnosticCount(env, "render-limit", "elements"), size_t(0));
         }},
    };
    for (const HostileCase& hostile : cases) {
        RenderEnv env(kEmpty);
        CHECK_EQ(env.env().eval(std::string(hostile.script) + " 'ok'"), std::string("ok"));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        const size_t heapBefore = heapInUse();
        bool built = false;
        onSmallStack(rt, [&] {
            try {
                env.rebuild();
                built = true;
            } catch (...) {
            }
        });
        const size_t heapAfter = heapInUse();
        CHECK(built);
        if (!built) {
            std::printf("  %s: the build failed\n", hostile.name);
            continue;
        }
        const size_t growth = heapAfter > heapBefore ? heapAfter - heapBefore : 0;
        std::printf("  %s: heap growth %.1f MB, %zu items\n", hostile.name, double(growth) / 1e6,
                    env.render().layerTree()->itemCount());
        CHECK(growth < kCeiling);
        hostile.check(env);

        // The same build under a budget: it stops inside the build, and the published state is the one before.
        litehtml::document* document = env.render().document();
        std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
        const std::string dump = env.render().layoutDump();
        env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + 1000);
        bool aborted = false;
        onSmallStack(rt, [&] { aborted = rebuildAborts(env); });
        CHECK(aborted);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
        CHECK(env.render().document() == document);
        CHECK(env.render().layerTree() == tree);
        CHECK_EQ(env.render().layoutDump(), dump);
        // Stops are final: a stopped runtime builds nothing.
        CHECK(rebuildAborts(env));
        CHECK(env.render().layerTree() == tree);
    }
}

WR_TEST(testFormControlLimit) {
    // 255 inputs, then a textarea (the 256th), then a select (the 257th: not rendered, nor its option) and a button;
    // the rest of the document still renders. In any namespace, by the lowercased name, as litehtml makes controls.
    RenderEnv env(kEmpty);
    CHECK_EQ(env.env().eval("for (let i = 0; i < 255; i++) document.body.appendChild(document.createElement('input'));"
                            "document.body.appendChild(document.createElement('textarea')).textContent = 't';"
                            "const s = document.body.appendChild(document.createElement('select'));"
                            "s.appendChild(document.createElement('option')).textContent = 'o';"
                            "document.body.appendChild(document.createElement('button')).textContent = 'b';"
                            "document.body.appendChild(document.createElementNS('http://www.w3.org/2000/svg', 'INPUT'));"
                            "document.body.appendChild(document.createElement('p')).textContent = 'after'; 'ok'"),
             std::string("ok"));
    env.rebuild();
    const std::string input = env.render().renderInput();
    CHECK_EQ(count(input, "<input>"), size_t(255));
    CHECK(input.find("<textarea>t</textarea>") != std::string::npos);
    CHECK(input.find("<select") == std::string::npos);
    CHECK(input.find("<option") == std::string::npos);
    CHECK(input.find("<button") == std::string::npos);
    CHECK(input.find("<INPUT") == std::string::npos);
    CHECK(input.find("<p>after</p>") != std::string::npos);
    CHECK_EQ(diagnosticCount(env, "render-limit", "form-controls"), size_t(1));
    CHECK(!lineFor(env.render().layoutDump(), "p").empty());
    // Each build posts it again, once.
    env.rebuild();
    CHECK_EQ(diagnosticCount(env, "render-limit", "form-controls"), size_t(2));
}

// I1: the DOM bounds no name's length, so a name is charged before it is converted. A 1,000,000-character tag name, or
// attribute name, stops the widget under a budget of 1,000 units with no allocation the size of the name.
WR_TEST(testLongNamesAreChargedBeforeConversion) {
    const char* const scripts[] = {
        "{ const e = document.createElement('a'.repeat(1000000)); e.setAttribute('b'.repeat(1000000), 'v');"
        " document.body.appendChild(e); }",
        "{ const e = document.createElement('div'); e.setAttribute('b'.repeat(1000000), 'v');"
        " document.body.appendChild(e); }",
    };
    for (const char* script : scripts) {
        RenderEnv env(kEmpty);
        CHECK_EQ(env.env().eval(std::string(script) + " 'ok'"), std::string("ok"));
        litehtml::document* published = env.render().document();
        JSRuntime* rt = env.env().runtime().jsRuntime();
        env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + 1000);
        const size_t heapBefore = heapInUse();
        gLargestAllocation = 0;
        gTrackAllocations = true;
        const bool aborted = rebuildAborts(env);
        gTrackAllocations = false;
        const size_t heapAfter = heapInUse();
        const size_t growth = heapAfter > heapBefore ? heapAfter - heapBefore : 0;
        CHECK(aborted);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
        CHECK(env.render().document() == published);
        CHECK(growth < 256 * 1024);
        CHECK(gLargestAllocation.load() < 256 * 1024);
        std::printf("  long names: heap growth %zu B, largest allocation %zu B\n", growth, gLargestAllocation.load());
    }
}

WR_TEST(testRenderInputIsKeptOnlyWhenAsked) {
    CHECK(!wr::RenderOptions().keepRenderInput);
    RenderEnv env("<!doctype html><p class=a>Hi <b>x</b></p>");
    env.rebuild();
    CHECK(!env.render().renderInput().empty());
    // Production's options: the same build, without the oracle.
    wr::RenderOptions production = env.options();
    production.keepRenderInput = false;
    wr::RenderTree tree(env.ctx(), env.host(), production);
    tree.rebuild(env.ctx());
    CHECK_EQ(tree.renderInput(), std::string());
    CHECK_EQ(tree.layoutDump(), env.render().layoutDump());
    CHECK(tree.layerTree() && tree.layerTree()->dump() == env.render().layerTree()->dump());
}

WR_TEST(testNoDocumentElement) {
    RenderEnv env("<!--a--><!--b-->");
    CHECK_EQ(env.env().eval("document.removeChild(document.documentElement); "
                            "document.childNodes.length + ':' + document.firstChild.nodeType"),
             std::string("2:8"));
    env.rebuild();
    CHECK_EQ(env.render().renderInput(), std::string("<!doctype html><html></html>"));
    const auto tags = dumpTags(env.render().layoutDump());
    CHECK(tags.size() == 1 && tags[0].second == "html");
}

WR_TEST(testNonHtmlDocumentElement) {
    RenderEnv env(kEmpty);
    CHECK_EQ(env.env().eval("const d = document.createElement('div'); d.textContent = 'x';"
                            "document.replaceChild(d, document.documentElement); document.documentElement.localName"),
             std::string("div"));
    env.rebuild();
    const auto tags = dumpTags(env.render().layoutDump());
    const bool asItIs = !tags.empty() && tags[0] == std::make_pair(size_t(0), std::string("div"));
    const bool wrapped = tags.size() >= 2 && tags[0] == std::make_pair(size_t(0), std::string("html")) &&
                         tags[1] == std::make_pair(size_t(1), std::string("div"));
    CHECK(asItIs || wrapped);
    std::printf("  non-html document element: %s\n", asItIs ? "laid out as it is" : wrapped ? "wrapped in html" : "?");
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    CHECK(tree && findText(*tree, "x") != nullptr);
}

WR_TEST(testLoadsGoThroughTheContainer) {
    RenderEnv env("<!doctype html><img src=http://x><div style=\"background:url(http://y)\">d</div>");
    CHECK(env.render().refusedLoads() >= 2);
    // A tree asks for nothing until it builds.
    wr::RenderTree fresh(env.ctx(), env.host(), env.options());
    CHECK_EQ(fresh.refusedLoads(), uint64_t(0));
    fresh.rebuild(env.ctx());
    CHECK(fresh.refusedLoads() >= 2);
    CHECK(env.host().decodedMimeTypes.empty());
}

namespace {

// A build whose charges are mostly in its layout pre-charge: 2,000 elements and a 100,000-byte word.
std::string atomicFixture(char letter) {
    std::string html = "<!doctype html><html><head></head><body>";
    for (int i = 0; i < 2000; i++) {
        html += "<div></div>";
    }
    return html + "<p id=t>" + std::string(100000, letter) + "</p></body></html>";
}

} // namespace

WR_TEST(testRebuildIsAtomic) {
    // The units one build of the fixture takes: charges do not depend on anything but the DOM.
    uint64_t units = 0;
    {
        RenderEnv env(atomicFixture('a'));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        const uint64_t before = JS_GetWorkUnits(rt);
        env.rebuild();
        units = JS_GetWorkUnits(rt) - before;
    }
    CHECK(units > 30000);
    // Inside the build (a third of the way), then inside the layout pre-charge (it is the last charge before
    // render(), and holds the 100,000-byte word's 12,500 units).
    const uint64_t limits[] = {units / 3, units - 1000};
    for (uint64_t limit : limits) {
        RenderEnv env(atomicFixture('a'));
        env.rebuild();
        litehtml::document* document = env.render().document();
        std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
        const std::string input = env.render().renderInput();
        const std::string dump = env.render().layoutDump();
        const uint64_t builds = env.render().buildCount();
        // The same length, so the next build charges the same.
        CHECK_EQ(env.env().eval("const t = document.getElementById('t').firstChild; t.data = 'b'.repeat(t.data.length);"
                                "t.data.length"),
                 std::string("100000"));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + limit);
        CHECK(rebuildAborts(env));
        CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
        CHECK(env.render().document() == document);
        CHECK(env.render().layerTree() == tree);
        CHECK_EQ(env.render().renderInput(), input);
        CHECK_EQ(env.render().layoutDump(), dump);
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK(input.find("bbbb") == std::string::npos);
        CHECK(tree && findText(*tree, std::string(100000, 'a')) != nullptr);
    }
}

WR_TEST(testRebuildReleasesNodes) {
    RenderEnv env(kEmpty);
    env.rebuild();
    env.env().eval("gc()");
    const size_t before = env.env().runtime().liveObjects();
    // Nothing here makes a platform object that outlives the script but the nodes (childNodes would: a [SameObject]).
    CHECK_EQ(env.env().eval("for (let i = 0; i < 100; i++) document.body.appendChild(document.createElement('div'))"
                            ".textContent = 't' + i; document.body.childElementCount"),
             std::string("100"));
    env.rebuild();
    CHECK(env.render().renderInput().find("<div>t99</div>") != std::string::npos);
    CHECK_EQ(env.env().eval("while (document.body.firstChild) document.body.firstChild.remove(); "
                            "document.body.childElementCount"),
             std::string("0"));
    // Removed and unreachable from script, the 200 nodes are still held by the published build's maps.
    env.env().eval("gc()");
    CHECK_EQ(env.env().runtime().liveObjects(), before + 200);
    env.rebuild();
    env.env().eval("gc()");
    CHECK_EQ(env.env().runtime().liveObjects(), before);
}

WR_TEST(testCacheWindowFollowsTheBuildOrder) {
    // Images asked for in layout and painting (get_image_size, draw_image), fonts made while styling and laying out,
    // and form controls: each build runs beginBuild, the build, finalize, render() and record(), then endBuild
    // (Ruling E10). In this fork nothing is asked for first during render() or record(): a font is made only by
    // css_properties::compute and an image loaded only by compute (backgrounds, list-style-image) and el_image's
    // compute_styles, all inside finalize. Probed shapes that ask nothing new in layout or painting: img, background,
    // list-style-image, ::before content url() and font, form controls (input, placeholder, textarea, select, button,
    // checkbox, range, meter), list markers, SVG text, use and image (SVG image loads nothing), mask-image,
    // border-image and image-set().
    RenderEnv env("<!doctype html><img src='" + kPng3x2 + "#img'><div style=\"background-image:url('" + kPng3x2 +
                  "#bg')\">bg</div><ul style=\"list-style-image:url('" + kPng3x2 +
                  "#marker')\"><li>item</li></ul><p style='font-family:serif'>serif <b>bold</b></p><input value=v>"
                  "<select><option>o</option></select><button>b</button>");
    env.rebuild();
    const size_t fonts = env.host().fontsCreated;
    const size_t images = env.host().decodedMimeTypes.size();
    CHECK(fonts > 0);
    CHECK_EQ(images, size_t(3));
    for (int i = 0; i < 3; i++) {
        env.rebuild();
        CHECK_EQ(env.host().fontsCreated, fonts);
        CHECK_EQ(env.host().decodedMimeTypes.size(), images);
    }
}
