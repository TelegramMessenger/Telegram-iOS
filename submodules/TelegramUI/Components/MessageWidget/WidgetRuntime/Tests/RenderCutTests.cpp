// The cut walk (RenderCut.h): renderCutDiff walks the DOM as a build walks it, deciding where every cap cuts and making
// nothing. Against the build of the same DOM it finds no node that differs, posts the same limits and ends with the same
// totals, at every cap.
#include <cstdio>
#include <string>
#include <unordered_set>

#include "Sources/DOM/DOM.h"
#include "Sources/Render/Builder.h"
#include "Sources/Render/RenderCut.h"
#include "Sources/Render/RenderTree.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

std::string page(const std::string& body) {
    return "<!doctype html><html><head></head><body>" + body + "</body></html>";
}

// Builds the DOM as `script` leaves it, then checks the walk against that build.
void expectTheWalkAgrees(const std::string& html, const std::string& script, const char* what) {
    RenderEnv env(html);
    if (!script.empty()) {
        CHECK_EQ(env.env().eval("(() => { " + script + "; })(); 'ok'"), std::string("ok"));
        env.buildAfresh();
    }
    const wr::RenderBuild& built = env.render().publishedBuild();
    const wr::RenderCutDiff diff = wr::renderCutDiff(env.ctx(), env.render().container(), built, {});
    const bool same = diff.nodes.empty() && diff.limits == built.limits && diff.end.bytes == built.bytes &&
                      diff.end.units.units == built.textUnits.units && diff.end.units.complex == built.textUnits.complex &&
                      diff.end.nodes == built.nodeCount && diff.end.elements == built.elementCount &&
                      diff.end.formControls == built.formControlCount &&
                      diff.end.litehtmlElements == built.document->build_elements();
    if (!same) {
        std::string a, b;
        for (const std::string& kind : diff.limits) a += kind + " ";
        for (const std::string& kind : built.limits) b += kind + " ";
        std::printf("  %s: %zu nodes differ; limits [%s] / [%s]; bytes %zu/%llu, units %zu/%zu, nodes %zu/%zu, elements "
                    "%zu/%zu, controls %zu/%zu, litehtml %d/%d\n",
                    what, diff.nodes.size(), a.c_str(), b.c_str(), diff.end.bytes, (unsigned long long)built.bytes,
                    diff.end.units.units, built.textUnits.units, diff.end.nodes, built.nodeCount, diff.end.elements,
                    built.elementCount, diff.end.formControls, built.formControlCount, diff.end.litehtmlElements,
                    built.document->build_elements());
    }
    CHECK(same);
}

} // namespace

WR_TEST(testTheCutWalkAgreesWithTheBuild) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    expectTheWalkAgrees(page("<p id=p class=a title=t>one <b>two</b></p><table> <tbody><tr><td>c</td></tr></tbody> </table>"),
                        "", "a plain page");
    expectTheWalkAgrees(page("<div id=d></div><p>after</p>"),
                        "for (let i = 0; i < 10050; i++) document.getElementById('d').appendChild(document.createElement('i'))",
                        "W's 10,000 elements");
    expectTheWalkAgrees(page("<div id=d></div><p>after</p>"),
                        "for (let i = 0; i < 260; i++) document.getElementById('d').appendChild(document.createElement('button'))",
                        "256 form controls");
    expectTheWalkAgrees(page("<p id=p>p</p><p>after</p>"),
                        "document.getElementById('p').setAttribute('style', 'color:red;' + ' '.repeat(17000))",
                        "the 16 KiB style attribute");
    expectTheWalkAgrees(page("<div id=d></div><p title=last>after</p>"),
                        "for (let i = 0; i < 5; i++) { const p = document.createElement('p'); p.title = 't'.repeat(60000);"
                        " document.getElementById('d').appendChild(p); }",
                        "a text attribute the text budget leaves out");
    expectTheWalkAgrees(page("<p id=big></p><p id=p>p</p><p>after</p>"),
                        "document.getElementById('big').className = 'x'.repeat(1048000);"
                        " document.getElementById('p').append('z'.repeat(1000))",
                        "the byte budget's stop");
    expectTheWalkAgrees(page("<div id=d></div><p>after</p>"),
                        "for (let i = 0; i < 5; i++) document.getElementById('d').appendChild(document.createElement('p')).textContent ="
                        " 'a'.repeat(60000)",
                        "262,144 text units");
    expectTheWalkAgrees(page("<div id=d></div><p>after</p>"),
                        "for (let i = 0; i < 2; i++) document.getElementById('d').appendChild(document.createElement('p')).textContent ="
                        " '\\u05d0'.repeat(5000)",
                        "8,192 complex units");
    expectTheWalkAgrees(page("<p id=p>p</p><p>after</p>"), "document.getElementById('p').append('a'.repeat(70000))",
                        "the text-node cap");
    expectTheWalkAgrees(page("<p>p</p>"),
                        "for (let i = 0; i < 2; i++) { const s = document.createElement('style'); s.textContent = 'p{color:red}' +"
                        " ' '.repeat(40000); document.body.appendChild(s); }",
                        "64 KiB of <style>");
    expectTheWalkAgrees(page("<div id=d></div><p>after</p>"),
                        "for (let i = 0; i < 50000; i++) document.getElementById('d').appendChild(document.createComment('c'))",
                        "the node cap's stop");
    expectTheWalkAgrees(page("<div id=d></div><p>after</p>"),
                        "let e = document.getElementById('d'); for (let i = 0; i < 260; i++) { const c = document.createElement('div');"
                        " e.appendChild(c); e = c; } e.append('deep')",
                        "depth 256");
    expectTheWalkAgrees(page("<p id=p></p><p id=q>a b c d e f g h</p><p>after</p>"),
                        "document.getElementById('p').append(Array(4997).fill('w').join(' '))",
                        "10,000 pieces, a Text straddling the cut");

    // A wanted node comes back with the state the build had before it: the document node, html and head.
    RenderEnv env(page("<p>x</p>"));
    wr::Node* body = nullptr;
    {
        wr::Element* html = wr::DOMState::of(env.ctx()).document().documentElementNode();
        for (size_t i = 0; html && i < html->childCount(); i++) {
            if (html->childAt(i)->isElement()) {
                body = html->childAt(i);
            }
        }
    }
    CHECK(body != nullptr);
    const wr::RenderCutDiff diff = wr::renderCutDiff(env.ctx(), env.render().container(), env.render().publishedBuild(), {body});
    CHECK_EQ(diff.nodes.size(), size_t(1));
    if (diff.nodes.size() == 1) {
        CHECK(diff.nodes[0].node == body);
        CHECK(diff.nodes[0].fate == wr::RenderFate::Rendered);
        CHECK_EQ(diff.nodes[0].before.nodes, size_t(3));
        CHECK_EQ(diff.nodes[0].before.elements, size_t(2));
        CHECK_EQ(diff.nodes[0].before.litehtmlElements, 2);
    }
}
