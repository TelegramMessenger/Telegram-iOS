// Edits no randomized oracle generates, and a long run of patches: every one patches (or changes nothing rendered), never
// builds after the boot and never stops the widget, and what it publishes is a fresh build's.
#include <cstdio>
#include <memory>
#include <string>
#include <tuple>

#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

// Whether the published layout, render input and layer tree are a fresh build's of the DOM as it now is.
bool matchesAFreshBuild(RenderEnv& env) {
    const auto [layout, input, layer] = wr_test::rebuildDump(env);
    const std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    return env.render().layoutDump() == layout && env.render().renderInput() == input &&
           (tree ? tree->dump() : std::string()) == layer;
}

struct Case {
    const char* name;
    std::string page;
    std::string script;
};

} // namespace

// Form controls and the head (profile 1 renders none of them), a <font> (a span), tables, SVG, lists, details, templates,
// sheets' attributes, the document element's children and its display, and <style> text around Ruling 7's 64 KiB.
WR_TEST(testEditsNoOracleGeneratesPatch) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    const std::string sel = "<body><select id=s><option id=o>a</option><option>b</option></select><p>t</p></body>";
    const std::string ta = "<body><textarea id=t>a</textarea><p>t</p></body>";
    const std::string in = "<body><input id=i placeholder=p><p>t</p></body>";
    const std::string pr = "<body><progress id=g value=1 max=3></progress><meter id=m value=0.3></meter><p>t</p></body>";
    const std::string fs = "<body><fieldset id=f><legend>L</legend><p id=fp>x</p></fieldset></body>";
    const std::string fo = "<body><font id=n color=red>x</font><p>t</p></body>";
    const std::string dl = "<body><datalist id=d><option>a</option></datalist>"
                           "<select><optgroup id=og label=g><option>a</option></optgroup></select></body>";
    const std::string tb = "<body><table id=tb><tbody><tr><td>x</td></tr></tbody></table><p>t</p></body>";
    const std::string svg = "<body><svg id=sv width=20 height=20><circle id=c r=3 cx=5 cy=5 fill=red /></svg><p>t</p></body>";
    const std::string head = "<head><title>x</title><link id=ln rel=icon href=data:,><base id=bs href=x></head>"
                             "<body><p>t</p><script id=sc>1</script></body>";
    const std::string ol = "<body><ol id=ol start=3><li id=li>a</li><li>b</li></ol></body>";
    const std::string det = "<body><details id=de><summary>s</summary>x</details><p>t</p></body>";
    const std::string tpl = "<body><template id=tp><p>x</p></template><p>t</p></body>";
    const std::string st = "<body><style id=st>p{color:red}</style><p>t</p></body>";
    const std::string plain = "<body><p>t</p></body>";
    // 53,490 and 19,890 bytes: together past Ruling 7's 64 KiB of <style> text.
    std::string big;
    for (int i = 0; i < 2600; i++) {
        big += ".r" + std::to_string(i) + "{color:#123456}";
    }
    std::string mid;
    for (int i = 0; i < 1000; i++) {
        mid += ".m" + std::to_string(i) + "{color:#123456}";
    }
    const std::string room = "<body><style id=a>" + big + "</style><style id=b>p{color:red}</style><p id=p>t</p></body>";
    const std::string past = "<body><style id=a>" + big + "</style><style id=b>" + mid + "</style><p id=p>t</p></body>";
    const Case cases[] = {
        {"option text", sel, "document.getElementById('o').textContent = 'c'"},
        {"option selected", sel, "document.getElementById('o').setAttribute('selected', '')"},
        {"select class", sel, "document.getElementById('s').className = 'x'"},
        {"option appended", sel, "document.getElementById('s').append(document.createElement('option'))"},
        {"option removed", sel, "document.getElementById('o').remove()"},
        {"select value", sel, "document.getElementById('s').value = 'b'"},
        {"textarea text", ta, "document.getElementById('t').textContent = 'b'"},
        {"textarea rows", ta, "document.getElementById('t').setAttribute('rows', '3')"},
        {"textarea value", ta, "document.getElementById('t').value = 'zz'"},
        {"input placeholder", in, "document.getElementById('i').setAttribute('placeholder', 'q')"},
        {"input value", in, "document.getElementById('i').value = 'v'"},
        {"input type", in, "document.getElementById('i').type = 'checkbox'"},
        {"input disabled", in, "document.getElementById('i').setAttribute('disabled', '')"},
        {"progress value attribute", pr, "document.getElementById('g').setAttribute('value', '2')"},
        {"progress value property", pr, "document.getElementById('g').value = 2.5"},
        {"meter value", pr, "document.getElementById('m').setAttribute('value', '0.6')"},
        {"progress class", pr, "document.getElementById('g').className = 'x'"},
        {"fieldset disabled", fs, "document.getElementById('f').setAttribute('disabled', '')"},
        {"fieldset child text", fs, "document.getElementById('fp').textContent = 'y'"},
        {"fieldset append", fs, "document.getElementById('f').append(document.createElement('div'))"},
        {"font color", fo, "document.getElementById('n').setAttribute('color', 'blue')"},
        {"datalist option text", dl, "document.querySelector('#d option').textContent = 'b'"},
        {"optgroup label", dl, "document.getElementById('og').setAttribute('label', 'h')"},
        {"a div appended to a table", tb, "document.getElementById('tb').append(document.createElement('div'))"},
        {"a tr appended to a table", tb, "document.getElementById('tb').append(document.createElement('tr'))"},
        {"table border", tb, "document.getElementById('tb').setAttribute('border', '1')"},
        {"td colspan", tb, "document.querySelector('td').setAttribute('colspan', '2')"},
        {"circle r", svg, "document.getElementById('c').setAttribute('r', '4')"},
        {"a rect appended to an svg", svg,
         "document.getElementById('sv').append(document.createElementNS('http://www.w3.org/2000/svg', 'rect'))"},
        {"svg width", svg, "document.getElementById('sv').setAttribute('width', '30')"},
        {"document.title", head, "document.title = 'y'"},
        {"link href", head, "document.getElementById('ln').setAttribute('href', 'data:,x')"},
        {"base href", head, "document.getElementById('bs').setAttribute('href', 'y')"},
        {"script text", head, "document.getElementById('sc').textContent = '2'"},
        {"a style appended to the head", head,
         "const s = document.createElement('style'); s.textContent = 'p{color:red}'; document.head.append(s)"},
        {"ol start", ol, "document.getElementById('ol').setAttribute('start', '5')"},
        {"li value", ol, "document.getElementById('li').setAttribute('value', '9')"},
        {"ol reversed", ol, "document.getElementById('ol').setAttribute('reversed', '')"},
        {"details open", det, "document.getElementById('de').setAttribute('open', '')"},
        {"template content", tpl, "document.getElementById('tp').content.firstChild.textContent = 'y'"},
        {"style media", st, "document.getElementById('st').setAttribute('media', '(max-width: 1px)')"},
        {"style disabled", st, "document.getElementById('st').disabled = true"},
        {"html lang", plain, "document.documentElement.setAttribute('lang', 'ru')"},
        {"a div appended to html", plain, "document.documentElement.append(document.createElement('div'))"},
        {"a comment appended", plain, "document.body.append(document.createComment('c'))"},
        {"canvas width", "<body><canvas id=cv width=10 height=10></canvas></body>", "document.getElementById('cv').width = 20"},
        {"img width", "<body><img id=im width=4 height=4 src='data:image/gif;base64,R0lGODlhAQABAAAAACw='></body>",
         "document.getElementById('im').setAttribute('width', '8')"},
        {"button text", "<body><button id=b>x</button></body>", "document.getElementById('b').textContent = 'y'"},
        {"q text", "<body><q id=q>x</q></body>", "document.getElementById('q').textContent = 'y'"},
        {"pre text", "<body><pre id=pre>a\nb</pre></body>", "document.getElementById('pre').textContent = 'c\\n d'"},
        {"a sheet grows past the room", room, "document.getElementById('b').textContent = '" + mid + "'"},
        {"a sheet appended past the room", room,
         "const s = document.createElement('style'); s.textContent = '" + mid + "'; document.body.append(s)"},
        {"the first sheet shrinks", past, "document.getElementById('a').textContent = 'p{color:blue}'"},
        {"the sheet past the room replaced", past, "document.getElementById('b').textContent = 'p{color:blue}'"},
        {"a class the first sheet names", past, "document.getElementById('p').className = 'r1'"},
        {"html hidden", plain, "document.documentElement.style.display = 'none'"},
        {"html shown", "<html style='display:none'><body><p>t</p></body></html>",
         "document.documentElement.style.display = ''"},
        {"html hidden by a class", "<style>.h{display:none}</style><body><p>t</p></body>",
         "document.documentElement.className = 'h'"},
        {"html shown by a class", "<html class=h><style>.h{display:none}</style><body><p>t</p></body></html>",
         "document.documentElement.className = ''"},
        {"body hidden", plain, "document.body.style.display = 'none'"},
        {"body shown", "<body style='display:none'><p>t</p></body>", "document.body.style.display = ''"},
    };
    for (const Case& c : cases) {
        RenderEnv env("<!doctype html>" + c.page);
        const uint64_t builds = env.render().buildCount();
        CHECK_EQ(env.env().eval("(() => { " + c.script + "; })(); 'ok'"), std::string("ok"));
        env.flush();
        const bool same = matchesAFreshBuild(env);
        if (env.render().buildCount() != builds || !same) {
            std::printf("  %s: %s (%s)\n", c.name, same ? "rebuilt" : "differs from a fresh build",
                        env.render().lastPatchRefusal());
        }
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        CHECK(same);
    }
}

// What only a rebuild used to reset never drifts: after a thousand patches of every kind, litehtml's counts, the published
// limits and the journal are a fresh build's, and the document was built once.
WR_TEST(testAThousandPatchesLeaveAFreshBuildsCounts) {
    RenderEnv env("<!doctype html><style id=s>q::before{content:'\\00ab'} .on{color:#c00}</style>"
                  "<body><ul id=l><li>a</li><li>b</li></ul><p id=p>text <q>quoted</q></p></body>");
    const char* const scripts[] = {
        "const li = document.createElement('li'); li.innerHTML = 'n <q>q</q>'; document.getElementById('l').append(li)",
        "const l = document.getElementById('l'); if (l.children.length > 2) l.lastElementChild.remove()",
        "document.getElementById('p').classList.toggle('on')",
        ("const s = document.getElementById('s'); s.textContent = s.textContent.includes('#c00')"
         " ? s.textContent.replace('#c00', '#0c0') : s.textContent.replace('#0c0', '#c00')"),
        "document.getElementById('p').firstChild.data = 'text ' + window.task",
    };
    for (int task = 0; task < 1000; task++) {
        const std::string script = "window.task = " + std::to_string(task) + "; " + scripts[(task * 7) % 5];
        CHECK_EQ(env.env().eval("(() => { " + script + "; })(); 'ok'"), std::string("ok"));
        env.flush();
    }
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    CHECK_EQ(env.render().buildCount(), uint64_t(1));
    CHECK_EQ(env.render().journalNodes(), size_t(0));
    CHECK(matchesAFreshBuild(env));
    CHECK(wr_test::countsMatchAFreshBuild(env, "a thousand patches"));
}
