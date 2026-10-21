// The WPT runner's pure parts (M1b plan, Task 17): URLs on the runner's origin, META headers and variants, page
// synthesis, the expectations format and its ratchet, the skip list, discovery, and the loader's refusals.
#include <unistd.h>

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>

#include "Tests/WPT/WPTSupport.h"
#include "Tests/wr_test.h"

namespace {

namespace fs = std::filesystem;

const std::string kPage = "http://web-platform.test:8000/dom/nodes/Node-cloneNode.html";

std::string tempRoot() {
    const char* base = std::getenv("TEST_TMPDIR");
    std::string pattern = std::string(base ? base : "/tmp") + "/wpt-support-XXXXXX";
    std::string path = pattern;
    char* made = mkdtemp(path.data());
    return made ? std::string(made) : std::string();
}

void writeFile(const std::string& path, const std::string& text) {
    fs::create_directories(fs::path(path).parent_path());
    std::ofstream out(path, std::ios::binary);
    out << text;
}

} // namespace

WR_TEST(testResolveURLOnTheRunnersOrigin) {
    using wr_wpt::resolveURL;
    CHECK(resolveURL(kPage, "/resources/testharness.js").value_or("") == "http://web-platform.test:8000/resources/testharness.js");
    CHECK(resolveURL(kPage, "attributes.js").value_or("") == "http://web-platform.test:8000/dom/nodes/attributes.js");
    CHECK(resolveURL(kPage, "../common.js").value_or("") == "http://web-platform.test:8000/dom/common.js");
    CHECK(resolveURL(kPage, "./support/a.js?x=1#f").value_or("") == "http://web-platform.test:8000/dom/nodes/support/a.js?x=1#f");
    CHECK(resolveURL(kPage, "  ../../common/gc.js \n").value_or("") == "http://web-platform.test:8000/common/gc.js");
    CHECK(resolveURL(kPage, "http://web-platform.test:8000/dom/x.js").value_or("") == "http://web-platform.test:8000/dom/x.js");
    CHECK(resolveURL(kPage, "//web-platform.test:8000/dom/x.js").value_or("") == "http://web-platform.test:8000/dom/x.js");
    CHECK(resolveURL(kPage, "?v=2").value_or("") == "http://web-platform.test:8000/dom/nodes/Node-cloneNode.html?v=2");
    CHECK(resolveURL(kPage, "#t").value_or("") == "http://web-platform.test:8000/dom/nodes/Node-cloneNode.html#t");
    // Other origins and schemes are refused, and so is climbing above the root.
    CHECK(!resolveURL(kPage, "https://example.com/x.js"));
    CHECK(!resolveURL(kPage, "//example.com/x.js"));
    CHECK(!resolveURL(kPage, "data:text/javascript,1"));
    CHECK(!resolveURL(kPage, "http://web-platform.test:80001/x.js"));
    CHECK(!resolveURL(kPage, "../../../x.js"));
}

WR_TEST(testPathOfDecodesAndRefusesDotSegments) {
    using wr_wpt::pathOf;
    CHECK(pathOf("http://web-platform.test:8000/dom/a%20b.js?q#f").value_or("") == "/dom/a b.js");
    CHECK(pathOf("http://web-platform.test:8000").value_or("") == "/");
    CHECK(!pathOf("http://web-platform.test:8000/dom/%2e%2e/%2e%2e/x"));
    CHECK(!pathOf("https://web-platform.test:8000/x"));
}

WR_TEST(testScriptMetaHeader) {
    wr_wpt::ScriptMeta meta = wr_wpt::parseScriptMeta(
        "// META: title=Events: once\n"
        "// META: script=/common/gc.js\n"
        "//META: script=resources/helper.js\n"
        "// META: timeout=long\n"
        "// META: variant=?1-10\n"
        "// META: variant=?11-last\n"
        "// some other comment\n"
        "\n"
        "// META: script=not-read.js\n"
        "test(() => {});\n");
    CHECK(meta.title == "Events: once");
    CHECK(meta.scripts.size() == 2 && meta.scripts[0] == "/common/gc.js" && meta.scripts[1] == "resources/helper.js");
    CHECK(meta.longTimeout);
    CHECK(meta.variants.size() == 2 && meta.variants[1] == "?11-last");
    CHECK(meta.window);
    CHECK(!wr_wpt::parseScriptMeta("// META: global=worker,shadowrealm\n").window);
    CHECK(wr_wpt::parseScriptMeta("// META: global=window,dedicatedworker\n").window);
    CHECK(wr_wpt::parseScriptMeta("// META: global=default\n").window);
}

WR_TEST(testHTMLMetaTags) {
    std::string html = "<!doctype html><meta charset=utf-8><META NAME=timeout content='long'>"
                       "<meta name=\"variant\" content=\"?a\"><meta content=\"?b\" name=variant><title>x</title>";
    CHECK(wr_wpt::htmlHasLongTimeout(html));
    std::vector<std::string> variants = wr_wpt::htmlVariants(html);
    CHECK(variants.size() == 2 && variants[0] == "?a" && variants[1] == "?b");
    CHECK(!wr_wpt::htmlHasLongTimeout("<meta name=timeout content=normal>"));
    CHECK(wr_wpt::isTestharnessPage("<script src=\"/resources/testharness.js\"></script>"));
    CHECK(!wr_wpt::isTestharnessPage("<script src=\"/resources/other.js\"></script>"));
}

WR_TEST(testSynthesizedPages) {
    wr_wpt::ScriptMeta meta;
    meta.title = "a<b";
    meta.scripts = {"/common/gc.js", "helper.js"};
    meta.longTimeout = true;
    std::string any = wr_wpt::synthesizePage("/dom/events/Foo.any.js", meta, true);
    CHECK(any.find("<title>a&lt;b</title>") != std::string::npos);
    CHECK(any.find("<meta name=\"timeout\" content=\"long\">") != std::string::npos);
    CHECK(any.find("self.GLOBAL = {") != std::string::npos);
    size_t harness = any.find("<script src=\"/resources/testharness.js\"></script>");
    size_t report = any.find("<script src=\"/resources/testharnessreport.js\"></script>");
    size_t gc = any.find("<script src=\"/common/gc.js\"></script>");
    size_t helper = any.find("<script src=\"helper.js\"></script>");
    size_t test = any.find("<script src=\"/dom/events/Foo.any.js\"></script>");
    CHECK(harness != std::string::npos && harness < report && report < gc && gc < helper && helper < test);
    std::string window = wr_wpt::synthesizePage("/dom/events/Bar.window.js", wr_wpt::ScriptMeta{}, false);
    CHECK(window.find("self.GLOBAL") == std::string::npos);
    CHECK(window.find("<script src=\"/dom/events/Bar.window.js\"></script>") != std::string::npos);
}

WR_TEST(testExpectationsRoundTripAndSort) {
    using wr_wpt::Record;
    std::vector<Record> records = {
        {"dom/b.html", false, "z", "FAIL"},
        {"dom/b.html", true, "", "OK"},
        {"dom/a.html", false, "tab\there\\ and\nnewline", "PASS"},
        {"dom/a.html", false, "#harness", "NOTRUN"},
        {"dom/a.html", true, "", "TIMEOUT"},
    };
    std::string text = wr_wpt::formatExpectations(records);
    std::vector<Record> parsed;
    std::string error;
    CHECK(wr_wpt::parseExpectations(text, &parsed, &error));
    CHECK(error.empty());
    CHECK(parsed.size() == 5);
    // Sorted by test, the harness record first, then subtests in byte order.
    CHECK(parsed[0].test == "dom/a.html" && parsed[0].harness && parsed[0].status == "TIMEOUT");
    CHECK(parsed[1].subtest == "#harness" && !parsed[1].harness && parsed[1].status == "NOTRUN");
    CHECK(parsed[2].subtest == "tab\there\\ and\nnewline");
    CHECK(parsed[3].test == "dom/b.html" && parsed[3].harness);
    CHECK(parsed[4].subtest == "z");
    CHECK(text.find("dom/a.html\t\\#harness\tNOTRUN\n") != std::string::npos);
    CHECK(text.find("dom/a.html\t#harness\tTIMEOUT\n") != std::string::npos);
    CHECK(text.find("tab\\there\\\\ and\\nnewline") != std::string::npos);
    // Malformed lines and unknown statuses are errors.
    CHECK(!wr_wpt::parseExpectations("dom/a.html\tx\n", &parsed, &error));
    CHECK(!wr_wpt::parseExpectations("dom/a.html\tx\tGOOD\n", &parsed, &error));
    CHECK(!wr_wpt::parseExpectations("dom/a.html\t#harness\tPASS\n", &parsed, &error));
    CHECK(!wr_wpt::parseExpectations("dom/a.html\tx\tPASS\ndom/a.html\tx\tFAIL\n", &parsed, &error));
}

WR_TEST(testTheRatchet) {
    using wr_wpt::Record;
    std::vector<Record> expected = {
        {"dom/a.html", true, "", "OK"},     {"dom/a.html", false, "a", "PASS"}, {"dom/a.html", false, "b", "FAIL"},
        {"dom/a.html", false, "c", "TIMEOUT"}, {"dom/a.html", false, "gone", "FAIL"}, {"dom/z.html", true, "", "OK"},
    };
    std::vector<Record> actual = {
        {"dom/a.html", true, "", "OK"},     {"dom/a.html", false, "a", "FAIL"},  {"dom/a.html", false, "b", "PASS"},
        {"dom/a.html", false, "c", "NOTRUN"}, {"dom/a.html", false, "d", "PASS"}, {"dom/a.html", false, "e", "FAIL"},
    };
    auto onlyA = [](std::string_view test) { return test == "dom/a.html"; };
    wr_wpt::Comparison c = wr_wpt::compare(expected, actual, onlyA);
    CHECK(!c.matches());
    CHECK(c.regressions.size() == 2);   // a PASS -> FAIL; "gone" not reported
    CHECK(c.improvements.size() == 2);  // b FAIL -> PASS; d new and passing
    CHECK(c.changes.size() == 2);       // c TIMEOUT -> NOTRUN (same rank); e new and failing
    // dom/z.html is out of scope (a filtered run), so its absence is not a regression.
    auto all = [](std::string_view) { return true; };
    CHECK(wr_wpt::compare(expected, actual, all).regressions.size() == 3);
    CHECK(wr_wpt::compare(expected, expected, all).matches());
}

WR_TEST(testSkipList) {
    std::vector<wr_wpt::SkipEntry> skips;
    std::string error;
    CHECK(wr_wpt::parseSkipList("# comment\n"
                                "dom/nodes/a.html\tiframe\tcreates an iframe\n"
                                "dom/events/b.any.js?1\tserver\tfetch\n",
                                &skips, &error));
    CHECK(skips.size() == 2);
    CHECK(wr_wpt::isSkipped(skips, "dom/nodes/a.html"));
    CHECK(wr_wpt::isSkipped(skips, "dom/nodes/a.html?v=1"));  // an entry without a variant covers every variant
    CHECK(wr_wpt::isSkipped(skips, "dom/events/b.any.js?1"));
    CHECK(!wr_wpt::isSkipped(skips, "dom/events/b.any.js?2"));
    CHECK(!wr_wpt::isSkipped(skips, "dom/nodes/a.htmlx"));
    CHECK(!wr_wpt::parseSkipList("dom/x.html\tbecause\tnote\n", &skips, &error));  // an unknown reason
    // A page that busy-waits on performance.now(), which the virtual clock never moves inside a script (V5e Task 5).
    CHECK(wr_wpt::parseSkipList("web-animations/x.html\tvirtual-clock\tspins on performance.now()\n", &skips, &error));
    CHECK(!wr_wpt::parseSkipList("dom/x.html\tiframe\n", &skips, &error));         // two fields
}

WR_TEST(testDiscoveryAndTheLoader) {
    std::string root = tempRoot();
    CHECK(!root.empty());
    writeFile(root + "/LICENSE.md", "license");
    writeFile(root + "/dom/a.html", "<script src=/resources/testharness.js></script>");
    writeFile(root + "/dom/b.html", "<p>not a test");
    writeFile(root + "/dom/c.any.js", "// META: variant=?1\n// META: variant=?2\ntest(() => {});\n");
    writeFile(root + "/dom/d.window.js", "test(() => {});\n");
    writeFile(root + "/dom/w.any.js", "// META: global=worker\ntest(() => {});\n");
    writeFile(root + "/dom/resources/e.html", "<script src=/resources/testharness.js></script>");
    writeFile(root + "/dom/f-manual.html", "<script src=/resources/testharness.js></script>");
    writeFile(root + "/dom/g.worker.js", "test(() => {});\n");
    writeFile(root + "/dom/h.html", "<meta name=variant content=?x><script src=/resources/testharness.js></script>");
    writeFile(root + "/dom/support.js", "var helper = 1;");
    writeFile(root + "/../outside.js", "var secret = 1;");
    std::error_code ec;
    fs::create_symlink(root + "/../outside.js", root + "/dom/link.js", ec);

    std::vector<wr_wpt::SkipEntry> skips = {{"dom/c.any.js?2", "server", "test"}};
    std::vector<wr_wpt::Page> pages = wr_wpt::discoverPages(root, {"dom"}, skips);
    std::vector<std::string> tests;
    for (const wr_wpt::Page& page : pages) {
        tests.push_back(page.test);
    }
    CHECK((tests == std::vector<std::string>{"dom/a.html", "dom/c.any.js?1", "dom/d.window.js", "dom/h.html?x"}));
    CHECK(pages[1].url == "http://web-platform.test:8000/dom/c.any.html?1");
    CHECK(pages[1].html.find("<script src=\"/dom/c.any.js\"></script>") != std::string::npos);
    CHECK(pages[2].url == "http://web-platform.test:8000/dom/d.window.html");
    CHECK(pages[3].url == "http://web-platform.test:8000/dom/h.html?x");

    wr_wpt::WPTLoader loader(root, "/* shim */");
    loader.setPageURL("http://web-platform.test:8000/dom/a.html");
    CHECK(loader.load("support.js").has_value() && loader.load("support.js")->text == "var helper = 1;");
    CHECK(loader.load("support.js")->url == "http://web-platform.test:8000/dom/support.js");
    CHECK(loader.load("/resources/testharnessreport.js").has_value() && loader.load("/resources/testharnessreport.js")->text == "/* shim */");
    CHECK(!loader.load("missing.js"));
    CHECK(!loader.load("link.js"));          // a symlink, here pointing outside the root
    CHECK(!loader.load("../../outside.js")); // climbing above the root
    CHECK(!loader.load("https://example.com/x.js"));
    CHECK(!loader.load("/dom"));             // a directory
    CHECK(loader.refused().size() >= 5);
    // The web-animations tests' helpers, two levels up (V5e plan, Task 5).
    writeFile(root + "/web-animations/testcommon.js", "var common = 1;");
    loader.setPageURL("http://web-platform.test:8000/web-animations/timing-model/animations/a.html");
    CHECK(loader.load("../../testcommon.js").has_value());
    fs::remove_all(root, ec);
    fs::remove(fs::path(root).parent_path() / "outside.js", ec);
}

WR_TEST(testTheLoaderRefusesASymlinkInsideTheRoot) {
    std::string root = tempRoot();
    CHECK(!root.empty());
    writeFile(root + "/LICENSE.md", "license");
    writeFile(root + "/dom/support.js", "var helper = 1;");
    std::error_code ec;
    fs::create_symlink(root + "/dom/support.js", root + "/dom/in.js", ec);
    CHECK(!ec);
    wr_wpt::WPTLoader loader(root, "/* shim */");
    loader.setPageURL("http://web-platform.test:8000/dom/a.html");
    CHECK(loader.load("support.js").has_value());
    // Its target is a file the loader serves under its own name, but a link is never followed.
    CHECK(!loader.load("in.js"));
    CHECK(loader.refused().size() == 1);
    fs::remove_all(root, ec);
}

WR_TEST(testTheLoaderServesOnlyTheDeclaredDirectories) {
    // What //third-party/wpt:TestFiles declares: resources/, common/, dom/, html/ and LICENSE.md.
    std::string root = tempRoot();
    CHECK(!root.empty());
    for (const char* file : {"/LICENSE.md", "/resources/r.js", "/common/c.js", "/dom/d.js", "/html/h.js",
                             "/interfaces/dom.idl", "/FILES.txt", "/VENDOR.md", "/domain/x.js"}) {
        writeFile(root + file, file);
    }
    wr_wpt::WPTLoader loader(root, "/* shim */");
    loader.setPageURL("http://web-platform.test:8000/dom/a.html");
    for (const char* url : {"/LICENSE.md", "/resources/r.js", "/common/c.js", "d.js", "/html/h.js"}) {
        CHECK(loader.load(url).has_value());
    }
    CHECK(!loader.load("/interfaces/dom.idl"));
    CHECK(!loader.load("../interfaces/dom.idl"));
    CHECK(!loader.load("/FILES.txt"));
    CHECK(!loader.load("/VENDOR.md"));
    CHECK(!loader.load("/domain/x.js"));  // a name starting "dom", not the directory
    CHECK(loader.refused().size() == 5);
    std::error_code ec;
    fs::remove_all(root, ec);
}
