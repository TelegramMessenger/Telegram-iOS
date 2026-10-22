// Profile 1's tables (V5c plan, Task 1): the generated Sources/Host/ProfileTables.inc against the vendored
// third-party/widget-sandbox/profile/profile.json it was made from, and the lookups CSS.supports and V4's validator use.
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>

#include "Sources/Host/Profile.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;
using wr::profile::CSSTable;
using wr::profile::ElementAction;
using wr::profile::MarkupTable;

namespace {

std::string profileJSON() {
    const char* path = std::getenv("WR_PROFILE_JSON");
    std::ifstream in(path ? path : "", std::ios::binary);
    std::stringstream s;
    s << in.rdbuf();
    return s.str();
}

std::string joined(std::span<const std::string_view> entries) {
    std::string out;
    for (std::string_view entry : entries) {
        out += out.empty() ? "" : "\n";
        out += entry;
    }
    return out;
}

std::string joined(CSSTable table) {
    return joined(wr::profile::table(table));
}

std::string joined(MarkupTable table) {
    return joined(wr::profile::table(table));
}

const char* actionName(ElementAction action) {
    switch (action) {
    case ElementAction::Keep:
        return "keep";
    case ElementAction::Span:
        return "span";
    case ElementAction::Div:
        return "div";
    case ElementAction::Drop:
        return "drop";
    }
    return "?";
}

/// html.elements as "name:action" lines, sorted by name.
std::string joinedActions() {
    std::string out;
    for (const wr::profile::NamedElementAction& entry : wr::profile::htmlElementActions()) {
        out += out.empty() ? "" : "\n";
        out += std::string(entry.name) + ":" + actionName(entry.action);
    }
    return out;
}

} // namespace

WR_TEST(testTheTablesAreTheProfiles) {
    HostEnv env;
    const std::string text = profileJSON();
    CHECK(!text.empty());
    JSContext* ctx = env.ctx();
    JSValue global = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global, "profileText", JS_NewStringLen(ctx, text.data(), text.size()));
    JS_FreeValue(ctx, global);
    env.eval("window.p = JSON.parse(profileText); window.c = p.tables.css;"
             "window.j = a => [...a].sort().join('\\n'); 1");
    const struct {
        CSSTable table;
        const char* source;
    } rows[] = {
        {CSSTable::Properties, "j(c.properties)"},
        {CSSTable::Functions, "j(c.functions)"},
        {CSSTable::Units, "j(c.units)"},
        {CSSTable::ValueSets, "j(Object.entries(c.values).flatMap(([k, v]) => v.map(x => k + ':' + x)))"},
        {CSSTable::ValuedProperties, "j(Object.keys(c.values))"},
        {CSSTable::PositionRewrites, "j(Object.keys(c.rewrite.position))"},
        {CSSTable::OverflowRewrites, "j(Object.keys(c.rewrite.overflow))"},
        {CSSTable::FilterFunctions, "j(c.filterFunctions)"},
        {CSSTable::Transform3D, "j(c.transform3d)"},
        {CSSTable::GenericFonts, "j(c.fonts.generic)"},
        {CSSTable::PseudoClasses, "j([...c.pseudoClasses, ...Object.keys(c.pseudoRewrite)])"},
        {CSSTable::PseudoElements, "j(c.pseudoElements)"},
        {CSSTable::ImageTypes, "j(p.tables.images)"},
        {CSSTable::AtRules, "j(c.atRules)"},
        {CSSTable::MediaTypes, "j(c.mediaTypes)"},
        {CSSTable::MediaFeatures, "j(c.mediaFeatures)"},
    };
    for (const auto& row : rows) {
        CHECK_EQ(joined(row.table), env.eval(row.source));
    }
    const struct {
        MarkupTable table;
        const char* source;
    } markupRows[] = {
        {MarkupTable::HTMLAttributes, "j(p.tables.html.attributes)"},
        {MarkupTable::HTMLAttributePrefixes, "j(p.tables.html.attributePrefixes)"},
        {MarkupTable::SVGElements, "j(p.tables.svg.elements.map(s => s.toLowerCase()))"},
        {MarkupTable::SVGAttributes, "j(p.tables.svg.attributes.map(s => s.toLowerCase()))"},
    };
    for (const auto& row : markupRows) {
        CHECK_EQ(joined(row.table), env.eval(row.source));
    }
    CHECK_EQ(joinedActions(), env.eval("j(Object.entries(p.tables.html.elements).map(([k, v]) => k + ':' + v))"));
    CHECK_EQ(std::string(wr::profile::defaultFont()), env.eval("c.fonts.default"));
    // The UA layer is the profile's text with each :where(X) written as X and nothing else changed: the @layer wrapper
    // stays, an origin of its own in the master (twidget edit 41; v0.1.1 plan, Task 2).
    CHECK_EQ(std::string(wr::profile::uaStylesheet()),
             env.eval("p.tables.uaStylesheet.replace(/:where\\(((?:[^()]|\\([^()]*\\))*)\\)/g, '$1')"));
    CHECK(std::string(wr::profile::uaStylesheet()).rfind("@layer tw-ua{", 0) == 0);
    CHECK_EQ(std::to_string(wr::profile::kVersion), env.eval("String(p.profile)"));
}

WR_TEST(testTheLookups) {
    using wr::profile::contains;
    CHECK(contains(CSSTable::Properties, "display"));
    CHECK(!contains(CSSTable::Properties, "behavior"));
    CHECK(contains(CSSTable::Functions, "calc"));
    CHECK(!contains(CSSTable::Functions, "expression"));
    CHECK(contains(CSSTable::Units, "px"));
    CHECK(contains(CSSTable::Transform3D, "rotatey"));
    CHECK(contains(CSSTable::PseudoClasses, "disabled"));
    CHECK(contains(CSSTable::ImageTypes, "image/png"));
    CHECK(wr::profile::kVersion == 1);
}

WR_TEST(testTheMarkupLookups) {
    using namespace wr::profile;
    CHECK(htmlElementAction("font") == ElementAction::Span);
    CHECK(htmlElementAction("center") == ElementAction::Div);
    CHECK(htmlElementAction("input") == ElementAction::Drop);
    CHECK(htmlElementAction("div") == ElementAction::Keep);
    CHECK(!htmlElementAction("style"));
    CHECK(!htmlElementAction("my-widget"));
    CHECK(unknownHTMLAction() == ElementAction::Span);
    CHECK(svgElementName("lineargradient") == std::optional<std::string_view>("linearGradient"));
    CHECK(!svgElementName("clippath"));
    CHECK(svgAttributeName("viewbox") == std::optional<std::string_view>("viewBox"));
    CHECK(fontAlias("blinkmacsystemfont") == std::optional<std::string_view>("system-ui"));
    CHECK(fontFallback("ui-rounded") == std::optional<std::string_view>("sans-serif"));
    CHECK(defaultFont() == "system-ui");
    CHECK(pseudoRewrite("enabled") == std::optional<std::string_view>(":not([disabled])"));
    CHECK(pseudoRewrite("disabled") == std::optional<std::string_view>("[disabled]"));
    CHECK(positionRewrite("-webkit-sticky") == std::optional<std::string_view>("relative"));
    CHECK(overflowRewrite("overlay") == std::optional<std::string_view>("hidden"));
    CHECK(contains(CSSTable::AtRules, "-webkit-keyframes"));
    CHECK(!contains(CSSTable::AtRules, "layer"));
    CHECK_EQ(joined(CSSTable::MediaTypes), std::string("all\nscreen"));
    CHECK(table(CSSTable::MediaFeatures).size() == 9);
    CHECK(contains(MarkupTable::HTMLAttributes, "colspan"));
    CHECK(!contains(MarkupTable::HTMLAttributes, "align"));
    CHECK(contains(MarkupTable::SVGAttributes, "viewbox"));
}

// Plan OP1: two lists the reference keeps outside profile.json (css-sanitizer.ts:62-72, allowlist.ts:63-66).
WR_TEST(testTheTwoReferenceLists) {
    CHECK_EQ(joined(MarkupTable::TextAttributes), std::string("alt\nlabel\nplaceholder\ntitle\nvalue"));
    CHECK_EQ(joined(MarkupTable::CSSValuedSVGAttributes),
             std::string("clip-path\ncolor\ncursor\nfill\nfilter\nflood-color\nlighting-color\nmarker\nmarker-end\n"
                         "marker-mid\nmarker-start\nmask\nstop-color\nstroke"));
}

WR_TEST(testTheProfileIsTheTables) {
    HostEnv env;
    CHECK_EQ(env.eval("String(TelegramWidget.profile)"), std::to_string(wr::profile::kVersion));
    CHECK_EQ(env.eval("String(TelegramWidget.isProfileAtLeast(" + std::to_string(wr::profile::kVersion) + "))"),
             std::string("true"));
}
