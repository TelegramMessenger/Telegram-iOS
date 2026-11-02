// html5lib's tree-construction tests (html5lib-tests 9329e64, vendored in third-party/gumbo) through OUR DOM: gumbo
// parses, the Builder makes the nodes (parseDocumentInto, parseFragment), and Html5libDump prints the DOM in
// html5lib's format. M1a's GumboHtml5libTests checks gumbo's own tree; this checks what the Builder makes of it (text
// runs, template contents, foreign attributes, source-text names). No case here reaches the Builder's limits or puts a
// NUL in a tag name: ParserTests covers those. Both run on gumbo's html5lib_dat.h, so the cases are read, skipped and
// counted as there: a case in the expected-failures file must fail, and one that starts passing, or does not run, fails
// the run until it is removed. A .dat that gives no case, or a total other than 1,792 cases in 57 files, fails it too.
//
// Usage: WidgetRuntimeBuilderHtml5libTests <expected-failures.txt> <file.dat>...
#include <memory>
#include <string>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Tests/Html5libDump.h"
#include "html5lib_dat.h"

namespace {

/// Our DOM's tree of the case, or "THREW" when the parse threw.
std::string ourTree(JSContext* ctx, const gumbo_test::Case& c) {
    try {
        wr::Ref<wr::Document> document = wr::Document::createHTML(ctx);
        if (c.fragmentContext.empty()) {
            wr::parseDocumentInto(ctx, *document, c.data);
            return wr_test::html5libDumpDocument(ctx, *document);
        }
        gumbo_test::FragmentContext context = gumbo_test::fragmentContextOf(c);
        wr::Namespace ns = context.ns == GUMBO_NAMESPACE_SVG ? wr::Namespace::SVG : context.ns == GUMBO_NAMESPACE_MATHML ? wr::Namespace::MathML : wr::Namespace::HTML;
        wr::Atom localName = wr::Atom::fromUTF8(ctx, context.localName);
        wr::Ref<wr::Element> element = wr::createElementNode(ctx, *document, ns, localName.get(), JS_ATOM_NULL, JS_ATOM_NULL);
        wr::Ref<wr::DocumentFragment> fragment = wr::parseFragment(ctx, *element, c.data);
        return wr_test::html5libDumpChildren(ctx, *fragment);
    } catch (...) {
        JS_FreeValue(ctx, JS_GetException(ctx));
        return "THREW\n";
    }
}

} // namespace

int main(int argc, char** argv) {
    std::unique_ptr<wr::Runtime> runtime = wr::Runtime::create({.interfaces = &wr::idl::kTable});
    JSContext* ctx = runtime->context();
    // Before the first parse: the element factory and the Builder read the DOM state's names.
    wr::installDOM(ctx, wr::Document::createHTML(ctx));
    int parsed = 0;
    auto treeOf = [&](const gumbo_test::Case& c) {
        // Each case is a parse of its own, as a widget's boot is: a batch of its own (limit.batch, widget-sandbox v0.3.0),
        // or the run's cases add up past 10,000 operations and every later one throws.
        runtime->startBatch();
        std::string tree = ourTree(ctx, c);
        // A parsed tree is cycles (a child's reference to its parent, a template's to its contents and back), which only
        // the collector frees: collect as the run goes, so its heap stays small.
        if (++parsed % 64 == 0) {
            JS_RunGC(runtime->jsRuntime());
        }
        return tree;
    };
    // gumbo's own tree, to tell a Builder difference from one gumbo's harness lists.
    auto explain = [](const gumbo_test::Case& c) {
        std::string tree = gumbo_test::gumboTree(c);
        return std::string("  gumbo (") + (tree == c.expected ? "passes: a Builder difference" : "fails too") + "):\n" + tree;
    };
    return gumbo_test::runSuite(argc, argv, treeOf, explain);
}
